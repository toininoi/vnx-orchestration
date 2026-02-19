#!/usr/bin/env python3
"""Retention/GC safety tests for session_gc.py (Phase H4)."""

import os
import sys
import time
from pathlib import Path

TEST_DIR = Path(__file__).resolve().parent
VNX_DIR = TEST_DIR.parent
SCRIPTS_DIR = VNX_DIR / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from session_gc import run_gc  # noqa: E402


def _set_old_mtime(path: Path) -> None:
    old_epoch = time.time() - (45 * 86400)
    os.utime(path, (old_epoch, old_epoch))


def _set_recent_mtime(path: Path) -> None:
    recent_epoch = time.time() - (1 * 86400)
    os.utime(path, (recent_epoch, recent_epoch))


def test_session_gc_dry_run_and_apply_with_protections(tmp_path):
    (tmp_path / "cache").mkdir(parents=True, exist_ok=True)
    (tmp_path / "dispatches" / "completed").mkdir(parents=True, exist_ok=True)
    (tmp_path / "dispatches" / "active").mkdir(parents=True, exist_ok=True)
    (tmp_path / "dispatches" / "pending").mkdir(parents=True, exist_ok=True)

    old_candidate = tmp_path / "cache" / "old.tmp"
    recent_file = tmp_path / "cache" / "new.tmp"
    audit_log = tmp_path / "dispatch_audit.jsonl"
    critical_receipt = tmp_path / "t0_receipts.ndjson"
    completed_dispatch = tmp_path / "dispatches" / "completed" / "old_dispatch.md"
    active_dispatch = tmp_path / "dispatches" / "active" / "active_dispatch.md"
    pending_dispatch = tmp_path / "dispatches" / "pending" / "pending_dispatch.md"

    for file_path in [
        old_candidate,
        recent_file,
        audit_log,
        critical_receipt,
        completed_dispatch,
        active_dispatch,
        pending_dispatch,
    ]:
        file_path.write_text("x", encoding="utf-8")

    for old_file in [
        old_candidate,
        audit_log,
        critical_receipt,
        completed_dispatch,
        active_dispatch,
        pending_dispatch,
    ]:
        _set_old_mtime(old_file)
    _set_recent_mtime(recent_file)

    dry_run_metrics = run_gc(days=14, state_dir=tmp_path, apply_changes=False)["gc"]
    assert dry_run_metrics["dry_run"] is True
    assert dry_run_metrics["scan"]["eligible_files"] == 1
    assert dry_run_metrics["delete"]["deleted_files"] == 0
    assert dry_run_metrics["candidates"][0]["path"] == "cache/old.tmp"
    assert old_candidate.exists()

    apply_metrics = run_gc(days=14, state_dir=tmp_path, apply_changes=True)["gc"]
    assert apply_metrics["dry_run"] is False
    assert apply_metrics["delete"]["deleted_files"] == 1
    assert not old_candidate.exists()

    # Protected files remain intact after apply.
    assert audit_log.exists()
    assert critical_receipt.exists()
    assert completed_dispatch.exists()
    assert active_dispatch.exists()
    assert pending_dispatch.exists()
