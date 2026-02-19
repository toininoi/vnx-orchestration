#!/usr/bin/env python3
"""
Sync Progress State From Receipts
================================

Purpose:
  Backfill/repair `$VNX_STATE_DIR/progress_state.yaml` using the most recent
  terminal receipts in `$VNX_STATE_DIR/t0_receipts.ndjson`.

Design:
  - Conservative by default: only applies updates when the newest receipt timestamp for a
    track is newer than the timestamp currently stored in progress_state.yaml.
  - Never overwrites an existing `active_dispatch_id` from receipts unless `--force-dispatch-id`
    is provided (receipts can contain non-file dispatch IDs or "N/A ...").
  - Writes atomically (temp file + rename).

Typical usage:
  python3 $VNX_HOME/scripts/sync_progress_state_from_receipts.py --apply
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

import yaml


SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))
sys.path.insert(0, str(SCRIPT_DIR))
try:
    from vnx_paths import ensure_env
except Exception as exc:
    raise SystemExit(f"Failed to load vnx_paths: {exc}")
try:
    from state_integrity import write_checksum
except Exception:
    write_checksum = None

PATHS = ensure_env()
STATE_DIR = PATHS["VNX_STATE_DIR"]

DEFAULT_PROGRESS_STATE_PATH = os.path.join(STATE_DIR, "progress_state.yaml")
DEFAULT_RECEIPTS_PATH = os.path.join(STATE_DIR, "t0_receipts.ndjson")

GATE_PROGRESSION: Dict[str, Optional[str]] = {
    "investigation": "planning",
    "planning": "implementation",
    "implementation": "review",
    "review": "testing",
    "testing": "integration",
    "integration": "quality_gate",
    "quality_gate": "planning",
    "validation": "planning",
    "escalation": None,
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _parse_iso_datetime(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    candidate = value.strip()
    candidate = candidate.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(candidate)
    except Exception:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed


def _terminal_to_track(terminal: Optional[str]) -> Optional[str]:
    if terminal == "T1":
        return "A"
    if terminal == "T2":
        return "B"
    if terminal == "T3":
        return "C"
    return None


def _meaningful_dispatch_id(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    candidate = str(value).strip()
    if not candidate:
        return None
    lowered = candidate.lower()
    if lowered.startswith("n/a"):
        return None
    if "self-initiated" in lowered:
        return None
    return candidate


def _default_track_state() -> Dict[str, Any]:
    return {
        "current_gate": "planning",
        "status": "idle",
        "active_dispatch_id": None,
        "last_receipt": {"event_type": None, "status": None, "timestamp": None, "dispatch_id": None},
        "history": [],
    }


def _initialize_state() -> Dict[str, Any]:
    return {
        "version": "1.0",
        "updated_at": _now_iso(),
        "updated_by": "initialization",
        "tracks": {"A": _default_track_state(), "B": _default_track_state(), "C": _default_track_state()},
    }


def _load_progress_state(path: str) -> Dict[str, Any]:
    if not os.path.exists(path):
        return _initialize_state()
    try:
        with open(path, "r") as handle:
            state = yaml.safe_load(handle) or {}
        if "tracks" not in state:
            return _initialize_state()
        for track in ("A", "B", "C"):
            state.setdefault("tracks", {}).setdefault(track, _default_track_state())
        return state
    except Exception:
        return _initialize_state()


def _atomic_write_yaml(path: str, payload: Dict[str, Any]) -> None:
    temp_path = f"{path}.tmp"
    with open(temp_path, "w") as handle:
        yaml.dump(payload, handle, default_flow_style=False, sort_keys=False)
    os.rename(temp_path, path)


@dataclass(frozen=True)
class TrackReceipt:
    timestamp: datetime
    event_type: Optional[str]
    status: Optional[str]
    dispatch_id: Optional[str]
    gate: Optional[str]


def _iter_recent_receipts(receipts_path: str, max_lines: int) -> Tuple[int, list[str]]:
    try:
        with open(receipts_path, "r") as handle:
            lines = handle.readlines()
    except FileNotFoundError:
        return 0, []
    except Exception:
        return 0, []

    if max_lines <= 0 or len(lines) <= max_lines:
        return len(lines), lines
    return len(lines), lines[-max_lines:]


def _extract_latest_receipts_by_track(receipts_path: str, max_lines: int) -> Dict[str, TrackReceipt]:
    _, lines = _iter_recent_receipts(receipts_path, max_lines=max_lines)

    latest: Dict[str, TrackReceipt] = {}
    for line in lines:
        raw = line.strip()
        if not raw:
            continue
        try:
            receipt = json.loads(raw)
        except Exception:
            continue

        terminal = receipt.get("terminal")
        track = receipt.get("track") or _terminal_to_track(terminal)
        if track not in ("A", "B", "C"):
            continue

        event_type = receipt.get("event_type") or receipt.get("event")
        status = receipt.get("status")
        dispatch_id = _meaningful_dispatch_id(receipt.get("dispatch_id"))
        gate = receipt.get("gate")
        timestamp = _parse_iso_datetime(receipt.get("timestamp")) or _parse_iso_datetime(receipt.get("sent_time"))
        if not timestamp:
            continue

        candidate = TrackReceipt(
            timestamp=timestamp,
            event_type=str(event_type) if event_type is not None else None,
            status=str(status) if status is not None else None,
            dispatch_id=dispatch_id,
            gate=str(gate) if gate is not None else None,
        )

        existing = latest.get(track)
        if existing is None or candidate.timestamp > existing.timestamp:
            latest[track] = candidate

    return latest


def _state_last_receipt_ts(track_state: Dict[str, Any]) -> Optional[datetime]:
    last_receipt = track_state.get("last_receipt") or {}
    return _parse_iso_datetime(last_receipt.get("timestamp"))


def _apply_receipt_to_track_state(
    track: str,
    track_state: Dict[str, Any],
    receipt: TrackReceipt,
    force_dispatch_id: bool,
) -> Dict[str, Any]:
    next_state = dict(track_state)

    last_receipt = dict(next_state.get("last_receipt") or {})
    last_receipt["event_type"] = receipt.event_type
    last_receipt["status"] = receipt.status
    last_receipt["timestamp"] = receipt.timestamp.isoformat()
    last_receipt["dispatch_id"] = receipt.dispatch_id
    next_state["last_receipt"] = last_receipt

    if receipt.gate:
        next_state["current_gate"] = receipt.gate

    if receipt.event_type == "task_started":
        next_state["status"] = "working"
        if receipt.dispatch_id and (force_dispatch_id or not next_state.get("active_dispatch_id")):
            next_state["active_dispatch_id"] = receipt.dispatch_id
        return next_state

    if receipt.event_type == "task_complete":
        if receipt.status == "success":
            next_state["status"] = "idle"
            next_state["active_dispatch_id"] = None
            if receipt.gate:
                next_gate = GATE_PROGRESSION.get(receipt.gate)
                if next_gate:
                    next_state["current_gate"] = next_gate
            return next_state

        next_state["status"] = "blocked"
        if receipt.dispatch_id and (force_dispatch_id or not next_state.get("active_dispatch_id")):
            next_state["active_dispatch_id"] = receipt.dispatch_id
        return next_state

    return next_state


def _append_history(track_state: Dict[str, Any], updated_by: str) -> Dict[str, Any]:
    history_entry = {
        "timestamp": _now_iso(),
        "gate": track_state.get("current_gate"),
        "status": track_state.get("status"),
        "dispatch_id": track_state.get("active_dispatch_id"),
        "updated_by": updated_by,
    }
    history = list(track_state.get("history") or [])
    track_state["history"] = ([history_entry] + history)[:10]
    return track_state


def main() -> int:
    parser = argparse.ArgumentParser(description="Backfill progress_state.yaml from recent receipts")
    parser.add_argument("--progress-state-path", default=DEFAULT_PROGRESS_STATE_PATH)
    parser.add_argument("--receipts-path", default=DEFAULT_RECEIPTS_PATH)
    parser.add_argument("--max-lines", type=int, default=5000)
    parser.add_argument("--apply", action="store_true", help="Write changes (otherwise dry-run)")
    parser.add_argument("--force-dispatch-id", action="store_true", help="Allow receipts to overwrite active_dispatch_id")
    parser.add_argument("--only-track", choices=["A", "B", "C"], help="Sync only one track")
    args = parser.parse_args()

    state = _load_progress_state(args.progress_state_path)
    latest_by_track = _extract_latest_receipts_by_track(args.receipts_path, max_lines=args.max_lines)

    updated_by = "sync_from_receipts"
    changes: Dict[str, Dict[str, Any]] = {}

    for track in ("A", "B", "C"):
        if args.only_track and track != args.only_track:
            continue

        receipt = latest_by_track.get(track)
        if not receipt:
            continue

        track_state = state["tracks"][track]
        current_ts = _state_last_receipt_ts(track_state)
        if current_ts and receipt.timestamp <= current_ts:
            continue

        new_track_state = _apply_receipt_to_track_state(
            track=track,
            track_state=track_state,
            receipt=receipt,
            force_dispatch_id=bool(args.force_dispatch_id),
        )
        new_track_state = _append_history(new_track_state, updated_by=updated_by)
        state["tracks"][track] = new_track_state

        changes[track] = {
            "applied_receipt_timestamp": receipt.timestamp.isoformat(),
            "event_type": receipt.event_type,
            "status": receipt.status,
            "dispatch_id": receipt.dispatch_id,
            "gate": receipt.gate,
            "new_current_gate": new_track_state.get("current_gate"),
            "new_status": new_track_state.get("status"),
            "new_active_dispatch_id": new_track_state.get("active_dispatch_id"),
        }

    state["updated_at"] = _now_iso()
    state["updated_by"] = updated_by

    if not changes:
        print("No updates needed (progress_state already newer than receipts).")
        return 0

    print(json.dumps({"changes": changes}, indent=2, sort_keys=True))

    if args.apply:
        os.makedirs(os.path.dirname(args.progress_state_path), exist_ok=True)
        _atomic_write_yaml(args.progress_state_path, state)
        print(f"✅ Updated: {args.progress_state_path}")
        if write_checksum:
            try:
                write_checksum(args.progress_state_path)
            except Exception as exc:
                print(f"Warning: failed to write checksum: {exc}", file=sys.stderr)
    else:
        print("Dry-run only. Re-run with --apply to write changes.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
