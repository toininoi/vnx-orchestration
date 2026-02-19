#!/usr/bin/env python3
"""Regression tests for dispatch identity extraction from reports."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
VNX_ROOT = TESTS_DIR.parent
SCRIPTS_DIR = VNX_ROOT / "scripts"
PROJECT_ROOT = TESTS_DIR.parents[3]


def _env(tmp_path: Path) -> dict:
    env = os.environ.copy()
    data_dir = tmp_path / "data"
    state_dir = data_dir / "state"
    state_dir.mkdir(parents=True, exist_ok=True)
    env["VNX_DATA_DIR"] = str(data_dir)
    env["VNX_STATE_DIR"] = str(state_dir)
    env["VNX_HOME"] = str(VNX_ROOT)
    env["PROJECT_ROOT"] = str(PROJECT_ROOT)
    return env


def _run_parser(tmp_path: Path, report_path: Path) -> dict:
    result = subprocess.run(
        [sys.executable, str(SCRIPTS_DIR / "report_parser.py"), str(report_path)],
        cwd=PROJECT_ROOT,
        env=_env(tmp_path),
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def test_extract_dispatch_id_from_dispatch_assignment_table(tmp_path: Path):
    report = tmp_path / "report.md"
    report.write_text(
        """# REPORT: sample

## Dispatch Assignment
| Field | Value |
|-------|-------|
| **PR** | PR-1 |
| **Dispatch-ID** | 20260218-151417-sse-correctness-and-contract-h-A |
| **Track** | A |
| **Gate** | gate_pr1_sse_contract |
""",
        encoding="utf-8",
    )

    payload = _run_parser(tmp_path, report)
    assert payload["dispatch_id"] == "20260218-151417-sse-correctness-and-contract-h-A"


def test_extract_dispatch_id_from_plain_field(tmp_path: Path):
    report = tmp_path / "report.md"
    report.write_text(
        """# REPORT: sample

Dispatch-ID: 20260218-152224-A-sse-contract-hygiene
""",
        encoding="utf-8",
    )

    payload = _run_parser(tmp_path, report)
    assert payload["dispatch_id"] == "20260218-152224-A-sse-contract-hygiene"
