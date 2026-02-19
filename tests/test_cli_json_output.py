#!/usr/bin/env python3
"""Minimal JSON output stability tests for CLI scripts."""

import json
import os
import subprocess
import sys
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
VNX_ROOT = TESTS_DIR.parent
PROJECT_ROOT = TESTS_DIR.parents[3]
SCRIPTS_DIR = VNX_ROOT / "scripts"


def _run_cli(tmp_path: Path, args):
    env = os.environ.copy()
    env["VNX_DATA_DIR"] = str(tmp_path)
    env["VNX_STATE_DIR"] = str(tmp_path / "state")
    env["VNX_SKILLS_DIR"] = str(PROJECT_ROOT / ".claude" / "skills")
    (tmp_path / "state").mkdir(parents=True, exist_ok=True)

    return subprocess.run(
        [sys.executable, *args],
        cwd=PROJECT_ROOT,
        env=env,
        capture_output=True,
        text=True,
    )


def test_gather_intelligence_validate_json(tmp_path):
    result = _run_cli(tmp_path, [str(SCRIPTS_DIR / "gather_intelligence.py"), "validate", "backend-developer"])
    assert result.returncode == 0
    payload = json.loads(result.stdout)
    assert "valid" in payload


def test_intelligence_queries_show_patterns_json(tmp_path):
    result = _run_cli(tmp_path, [str(SCRIPTS_DIR / "intelligence_queries.py"), "show_patterns", "test"])
    assert result.returncode == 0
    payload = json.loads(result.stdout)
    assert payload["ok"] is True
    assert isinstance(payload["data"], list)
    assert payload["error_code"] is None
    assert payload["error_msg"] is None


def test_check_intelligence_health_json(tmp_path):
    result = _run_cli(tmp_path, [str(SCRIPTS_DIR / "check_intelligence_health.py")])
    payload = json.loads(result.stdout)
    assert "health_status" in payload
    expected_code = 0 if payload.get("health_status") == "healthy" else 11
    assert result.returncode == expected_code


def test_gather_intelligence_invalid_agent_payload(tmp_path):
    result = _run_cli(tmp_path, [str(SCRIPTS_DIR / "gather_intelligence.py"), "gather", "do thing", "T1", "not-a-skill"])
    payload = json.loads(result.stdout)
    assert payload.get("dispatch_blocked") is True
    assert "available_agents" in payload
    assert "suggested_agent" in payload
