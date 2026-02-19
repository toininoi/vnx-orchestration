#!/usr/bin/env python3
"""Tests for stdin dispatch mode in heartbeat_ack_monitor."""

from __future__ import annotations

import json
from datetime import datetime, timezone
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from heartbeat_ack_monitor import run_stdin_monitor


class _FakeMonitor:
    def __init__(self) -> None:
        self.active_dispatches = {}
        self.calls = []

    def track_dispatch(self, dispatch_id, terminal, task_id, sent_time, pr_id=""):
        self.calls.append(
            {
                "dispatch_id": dispatch_id,
                "terminal": terminal,
                "task_id": task_id,
                "sent_time": sent_time,
                "pr_id": pr_id,
            }
        )
        # Do not populate active_dispatches so stdin mode exits immediately.


def test_run_stdin_monitor_tracks_dispatch_without_wrapper():
    payload = {
        "dispatch_id": "DISP-100",
        "terminal": "T1",
        "task_id": "TASK-100",
        "sent_time": "2026-02-11T12:00:00Z",
        "pr_id": "PR-100",
    }

    monitor = _FakeMonitor()
    exit_code = run_stdin_monitor(json.dumps(payload), monitor=monitor)

    assert exit_code == 0
    assert len(monitor.calls) == 1

    call = monitor.calls[0]
    assert call["dispatch_id"] == payload["dispatch_id"]
    assert call["terminal"] == payload["terminal"]
    assert call["task_id"] == payload["task_id"]
    assert call["pr_id"] == payload["pr_id"]
    assert isinstance(call["sent_time"], datetime)
    assert call["sent_time"].tzinfo == timezone.utc
