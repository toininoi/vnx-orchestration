#!/usr/bin/env python3
"""Static checks ensuring wrapper removal for AS-09."""

from __future__ import annotations

from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
VNX_ROOT = TESTS_DIR.parent
SCRIPTS_DIR = VNX_ROOT / "scripts"


def test_dispatch_ack_watcher_invokes_ack_monitor_directly():
    content = (SCRIPTS_DIR / "dispatch_ack_watcher.sh").read_text(encoding="utf-8")
    assert "heartbeat_ack_monitor_wrapper.py" not in content
    assert "heartbeat_ack_monitor.py" in content
    assert "--stdin" in content


def test_pr_queue_completion_attempt_inlines_event_logging():
    content = (SCRIPTS_DIR / "pr_queue_manager.py").read_text(encoding="utf-8")
    assert "def log_completion_attempt" not in content
    assert "completion_attempt" in content
    assert "log_queue_event" in content
