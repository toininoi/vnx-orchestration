#!/usr/bin/env python3
"""Error-contract regression tests for generate_t0_brief.sh (AS-03 residual hardening)."""

from __future__ import annotations

import json
import os
import stat
import subprocess
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = TESTS_DIR.parents[2]
VNX_ROOT = TESTS_DIR.parent
SCRIPT_PATH = VNX_ROOT / "scripts" / "generate_t0_brief.sh"


def _env(tmp_path: Path) -> dict:
    data_dir = tmp_path / "data"
    state_dir = data_dir / "state"
    dispatch_dir = data_dir / "dispatches"

    for name in ("queue", "pending", "active", "conflicts"):
        (dispatch_dir / name).mkdir(parents=True, exist_ok=True)
    state_dir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["VNX_HOME"] = str(VNX_ROOT)
    env["PROJECT_ROOT"] = str(PROJECT_ROOT)
    env["VNX_DATA_DIR"] = str(data_dir)
    env["VNX_STATE_DIR"] = str(state_dir)
    env["VNX_DISPATCH_DIR"] = str(dispatch_dir)
    return env


def _run(env: dict) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(SCRIPT_PATH)],
        cwd=PROJECT_ROOT,
        env=env,
        capture_output=True,
        text=True,
    )


def test_generate_t0_brief_critical_failure_fails_closed_with_structured_error(tmp_path: Path):
    env = _env(tmp_path)

    fake_bin = tmp_path / "fake-bin"
    fake_bin.mkdir(parents=True, exist_ok=True)
    fake_python = fake_bin / "python3"
    fake_python.write_text("#!/usr/bin/env bash\nexit 31\n", encoding="utf-8")
    fake_python.chmod(fake_python.stat().st_mode | stat.S_IEXEC)
    env["PATH"] = f"{fake_bin}:{env.get('PATH', '')}"

    result = _run(env)

    assert result.returncode != 0
    assert not (Path(env["VNX_STATE_DIR"]) / "t0_brief.json").exists()

    error_log = Path(env["VNX_STATE_DIR"]) / "t0_brief_errors.log"
    assert error_log.exists()
    payload = error_log.read_text(encoding="utf-8")
    assert '"event":"failure"' in payload
    assert '"classification":"critical"' in payload
    assert '"code":"brief_json_generation_failed"' in payload


def test_generate_t0_brief_non_critical_history_failure_warns_and_continues(tmp_path: Path):
    env = _env(tmp_path)
    history_dir = Path(env["VNX_STATE_DIR"]) / "t0_brief_history"
    history_dir.mkdir(parents=True, exist_ok=True)

    original_mode = history_dir.stat().st_mode
    history_dir.chmod(0o500)
    try:
        result = _run(env)
    finally:
        history_dir.chmod(original_mode)

    assert result.returncode == 0

    out_json = Path(env["VNX_STATE_DIR"]) / "t0_brief.json"
    assert out_json.exists()
    json.loads(out_json.read_text(encoding="utf-8"))

    error_log = Path(env["VNX_STATE_DIR"]) / "t0_brief_errors.log"
    payload = error_log.read_text(encoding="utf-8")
    assert '"event":"warning"' in payload
    assert '"classification":"non_critical"' in payload
    assert '"code":"history_snapshot_failed"' in payload


def test_generate_t0_brief_terminal_snapshot_not_degraded(tmp_path: Path):
    """Verify canonical_state_views.py imports resolve correctly (PYTHONPATH fix)."""
    env = _env(tmp_path)
    state_dir = Path(env["VNX_STATE_DIR"])

    # Seed a valid terminal_state.json matching the schema vnx start produces
    terminal_state = {
        "schema_version": 1,
        "terminals": {
            "T1": {"terminal_id": "T1", "status": "idle", "last_activity": "2026-01-01T00:00:00+00:00", "version": 1},
            "T2": {"terminal_id": "T2", "status": "idle", "last_activity": "2026-01-01T00:00:00+00:00", "version": 1},
            "T3": {"terminal_id": "T3", "status": "idle", "last_activity": "2026-01-01T00:00:00+00:00", "version": 1},
        },
    }
    (state_dir / "terminal_state.json").write_text(
        json.dumps(terminal_state), encoding="utf-8"
    )

    result = _run(env)
    assert result.returncode == 0

    brief = json.loads((state_dir / "t0_brief.json").read_text(encoding="utf-8"))

    # Terminal status must NOT be "offline" (which indicates degraded fallback)
    for t in ("T1", "T2", "T3"):
        status = brief.get("terminals", {}).get(t, {}).get("status", "offline")
        assert status != "offline", (
            f"{t} status is 'offline' — canonical_state_views.py import likely failed"
        )

    # The error log should NOT contain terminal_snapshot_unavailable
    error_log = state_dir / "t0_brief_errors.log"
    if error_log.exists():
        content = error_log.read_text(encoding="utf-8")
        assert "terminal_snapshot_unavailable" not in content
