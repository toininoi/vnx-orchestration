#!/usr/bin/env python3
"""AS-06 regression tests for standard Result contract and exit code mapping."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
VNX_ROOT = TESTS_DIR.parent
PROJECT_ROOT = TESTS_DIR.parents[3]
SCRIPTS_DIR = VNX_ROOT / "scripts"


def _env(tmp_path: Path) -> dict:
    env = os.environ.copy()
    data_dir = tmp_path / "data"
    state_dir = data_dir / "state"
    dispatch_dir = data_dir / "dispatches"
    state_dir.mkdir(parents=True, exist_ok=True)
    dispatch_dir.mkdir(parents=True, exist_ok=True)
    env["VNX_HOME"] = str(VNX_ROOT)
    env["PROJECT_ROOT"] = str(PROJECT_ROOT)
    env["VNX_DATA_DIR"] = str(data_dir)
    env["VNX_STATE_DIR"] = str(state_dir)
    env["VNX_DISPATCH_DIR"] = str(dispatch_dir)
    return env


def _run(tmp_path: Path, script: str, args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPTS_DIR / script), *args],
        cwd=PROJECT_ROOT,
        env=_env(tmp_path),
        capture_output=True,
        text=True,
    )


def _json_payload(output: str) -> dict:
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            return json.loads(line)
    raise AssertionError(f"No JSON payload found in output:\n{output}")


def test_result_contract_shape_success_and_failure():
    sys.path.insert(0, str(SCRIPTS_DIR / "lib"))
    from result_contract import result_error, result_ok

    success = result_ok({"foo": "bar"}).to_dict()
    failure = result_error("missing_argument", "Example").to_dict()

    expected_keys = {"ok", "data", "error_code", "error_msg"}
    assert set(success.keys()) == expected_keys
    assert set(failure.keys()) == expected_keys
    assert success["ok"] is True and success["error_code"] is None
    assert failure["ok"] is False and failure["error_code"] == "missing_argument"


def test_intelligence_queries_success_result_shape(tmp_path: Path):
    result = _run(tmp_path, "intelligence_queries.py", ["show_patterns", "test"])

    assert result.returncode == 0
    payload = _json_payload(result.stdout)
    assert payload["ok"] is True
    assert isinstance(payload["data"], list)
    assert payload["error_code"] is None
    assert payload["error_msg"] is None


def test_intelligence_queries_failure_result_shape_and_exit(tmp_path: Path):
    result = _run(tmp_path, "intelligence_queries.py", ["show_patterns"])

    assert result.returncode == 10
    payload = _json_payload(result.stdout)
    assert payload["ok"] is False
    assert payload["data"] is None
    assert payload["error_code"] == "missing_argument"
    assert "show_patterns requires <query>" in payload["error_msg"]


def test_pr_queue_manager_unknown_command_maps_to_validation_exit(tmp_path: Path):
    result = _run(tmp_path, "pr_queue_manager.py", ["no_such_command"])
    assert result.returncode == 10
    assert "Unknown command: no_such_command" in result.stdout


def test_pr_queue_manager_show_missing_dispatch_maps_to_io_exit(tmp_path: Path):
    result = _run(tmp_path, "pr_queue_manager.py", ["show", "missing-dispatch"])
    assert result.returncode == 20
    assert "Staging dispatch not found" in result.stdout
