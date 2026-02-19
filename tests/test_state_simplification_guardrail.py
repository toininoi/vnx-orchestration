#!/usr/bin/env python3
"""Guardrail harness for VNX state simplification (S1).

Validates:
- Canonical root resolution (VNX_STATE_DIR)
- No unexpected new writers to legacy state root
- Critical state files exist and are parseable
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from fnmatch import fnmatch
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))
sys.path.insert(0, str(SCRIPT_DIR))

try:
    from vnx_paths import ensure_env
except Exception as exc:
    raise SystemExit(f"Failed to load vnx_paths: {exc}")

try:
    import yaml
except Exception as exc:
    raise SystemExit(f"Missing dependency for YAML parsing: {exc}")


CRITICAL_FILES = {
    "dashboard_status.json": "json",
    "progress_state.yaml": "yaml",
    "t0_brief.json": "json",
    "t0_receipts.ndjson": "ndjson",
    "panes.json": "json",
    "terminal_status.ndjson": "ndjson",
}


def _is_relative_to(path: Path, base: Path) -> bool:
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


def _load_allowlist(value: str, allowlist_path: Path | None) -> List[str]:
    if value:
        return [item.strip() for item in value.split(",") if item.strip()]
    if allowlist_path and allowlist_path.exists():
        return [
            line.strip()
            for line in allowlist_path.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.strip().startswith("#")
        ]
    return []


def _env_flag(name: str) -> Optional[bool]:
    value = os.environ.get(name)
    if value is None:
        return None
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _rollback_mode_enabled() -> bool:
    rollback = _env_flag("VNX_STATE_SIMPLIFICATION_ROLLBACK")
    if rollback is None:
        rollback = _env_flag("VNX_STATE_DUAL_WRITE_LEGACY")
    return bool(rollback)


def _read_json(path: Path) -> None:
    with path.open("r", encoding="utf-8") as handle:
        json.load(handle)


def _read_yaml(path: Path) -> None:
    with path.open("r", encoding="utf-8") as handle:
        yaml.safe_load(handle)


def _read_ndjson(path: Path) -> Tuple[int, int]:
    total = 0
    parsed = 0
    with path.open("r", encoding="utf-8") as handle:
        for idx, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            total += 1
            try:
                json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"Invalid NDJSON at line {idx}: {exc}")
            parsed += 1
    return total, parsed


def _check_canonical_root(paths: dict) -> List[str]:
    errors: List[str] = []
    vnx_home = Path(paths["VNX_HOME"]).resolve()
    vnx_data_dir = Path(paths["VNX_DATA_DIR"]).resolve()
    vnx_state_dir = Path(paths["VNX_STATE_DIR"]).resolve()

    if not vnx_state_dir.exists():
        errors.append(f"VNX_STATE_DIR missing: {vnx_state_dir}")
        return errors

    legacy_state_dir = vnx_home / "state"

    if _is_relative_to(vnx_state_dir, legacy_state_dir):
        errors.append(f"VNX_STATE_DIR resolves to legacy root: {vnx_state_dir}")

    if not _is_relative_to(vnx_state_dir, vnx_data_dir):
        errors.append(
            "VNX_STATE_DIR is not under VNX_DATA_DIR "
            f"(VNX_STATE_DIR={vnx_state_dir}, VNX_DATA_DIR={vnx_data_dir})"
        )

    expected_default = (vnx_data_dir / "state").resolve()
    if vnx_state_dir != expected_default:
        errors.append(
            "VNX_STATE_DIR does not match canonical default "
            f"(expected {expected_default}, got {vnx_state_dir})"
        )

    return errors


def _recent_legacy_writes(
    legacy_root: Path,
    window_seconds: int,
    allowlist: Iterable[str],
) -> List[Tuple[Path, float]]:
    now = time.time()
    allowed = list(allowlist)
    offenders: List[Tuple[Path, float]] = []

    if not legacy_root.exists():
        return offenders

    for path in legacy_root.rglob("*"):
        if not path.is_file():
            continue
        if any(fnmatch(path.name, pattern) for pattern in allowed):
            continue
        age = now - path.stat().st_mtime
        if age <= window_seconds:
            offenders.append((path, age))

    return offenders


def _check_critical_files(state_dir: Path) -> Tuple[List[str], List[str]]:
    errors: List[str] = []
    warnings: List[str] = []

    for name, kind in CRITICAL_FILES.items():
        path = state_dir / name
        if not path.exists():
            errors.append(f"Missing critical file: {path}")
            continue
        if path.stat().st_size == 0:
            warnings.append(f"Empty critical file: {path}")
            continue
        try:
            if kind == "json":
                _read_json(path)
            elif kind == "yaml":
                _read_yaml(path)
            elif kind == "ndjson":
                total, parsed = _read_ndjson(path)
                if total == 0:
                    warnings.append(f"NDJSON empty: {path}")
                elif total != parsed:
                    warnings.append(f"NDJSON parsed {parsed}/{total}: {path}")
            else:
                errors.append(f"Unknown file type '{kind}' for {path}")
        except Exception as exc:
            errors.append(f"Failed to parse {path}: {exc}")

    return errors, warnings


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="VNX state simplification guardrail harness")
    parser.add_argument(
        "--legacy-write-window-seconds",
        type=int,
        default=int(os.environ.get("VNX_LEGACY_WRITE_WINDOW_SECONDS", "3600")),
        help="Detect legacy writes within this window (default: 3600s).",
    )
    parser.add_argument(
        "--legacy-write-allowlist",
        default=None,
        help="Comma-separated legacy filenames allowed to update.",
    )
    parser.add_argument(
        "--legacy-write-allowlist-file",
        default=None,
        help="Path to allowlist file (one glob pattern per line).",
    )
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    paths = ensure_env()

    errors: List[str] = []
    warnings: List[str] = []

    errors.extend(_check_canonical_root(paths))

    legacy_root = Path(paths["VNX_HOME"]).resolve() / "state"
    rollback_mode = _rollback_mode_enabled()
    allowlist_file = Path(args.legacy_write_allowlist_file).expanduser().resolve() if args.legacy_write_allowlist_file else None
    if allowlist_file is None:
        default_allowlist = SCRIPT_DIR / "state_simplification_legacy_allowlist.txt"
        allowlist_file = default_allowlist if default_allowlist.exists() else None

    allowlist_value = args.legacy_write_allowlist
    if allowlist_value is None:
        allowlist_value = os.environ.get("VNX_LEGACY_WRITE_ALLOWLIST", "")
    if args.legacy_write_allowlist_file is None:
        env_allowlist_file = os.environ.get("VNX_LEGACY_WRITE_ALLOWLIST_FILE", "")
        if env_allowlist_file:
            allowlist_file = Path(env_allowlist_file).expanduser().resolve()

    allowlist = []
    if rollback_mode or allowlist_value or args.legacy_write_allowlist_file:
        allowlist = _load_allowlist(allowlist_value or "", allowlist_file)
    recent = _recent_legacy_writes(legacy_root, args.legacy_write_window_seconds, allowlist)
    if recent:
        errors.append("Unexpected legacy state writes detected:")
        for path, age in sorted(recent, key=lambda item: item[1]):
            errors.append(f"  - {path} (modified {int(age)}s ago)")

    state_dir = Path(paths["VNX_STATE_DIR"]).resolve()
    parse_errors, parse_warnings = _check_critical_files(state_dir)
    errors.extend(parse_errors)
    warnings.extend(parse_warnings)

    print("VNX state simplification guardrail")
    print(f"VNX_STATE_DIR={state_dir}")
    print(f"Legacy state root={legacy_root}")
    print(f"Legacy write window={args.legacy_write_window_seconds}s")
    print(f"Legacy write mode={'rollback' if rollback_mode else 'archived'}")
    if allowlist:
        print(f"Legacy allowlist={', '.join(allowlist)}")

    if warnings:
        print("\nWarnings:")
        for warning in warnings:
            print(f"- {warning}")

    if errors:
        print("\nFailures:")
        for error in errors:
            print(error)
        return 1

    print("\nStatus: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
