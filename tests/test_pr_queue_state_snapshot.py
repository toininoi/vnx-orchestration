#!/usr/bin/env python3
"""Unit tests for PR queue state snapshot helper."""

from datetime import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts" / "lib"))

from pr_queue_state_snapshot import build_vnx_state_snapshot


def test_build_snapshot_includes_next_available_and_execution_order():
    state = {
        "feature": "AS-02",
        "completed": ["PR-1"],
        "active": ["PR-2"],
        "blocked": ["PR-4"],
        "prs": [
            {"id": "PR-1", "status": "completed", "dependencies": []},
            {"id": "PR-2", "status": "in_progress", "dependencies": ["PR-1"]},
            {"id": "PR-3", "status": "queued", "dependencies": ["PR-2"]},
            {"id": "PR-4", "status": "blocked", "dependencies": []},
        ],
    }

    snapshot = build_vnx_state_snapshot(state, True, ["PR-1", "PR-2", "PR-3"])

    assert snapshot["active_feature"] == {"name": "AS-02", "plan_file": "FEATURE_PLAN.md"}
    assert snapshot["completed_prs"] == ["PR-1"]
    assert snapshot["in_progress"] == ["PR-2"]
    assert snapshot["blocked"] == ["PR-4"]
    assert snapshot["next_available"] == []
    assert snapshot["execution_order"] == ["PR-1", "PR-2", "PR-3"]
    datetime.fromisoformat(snapshot["updated_at"])


def test_build_snapshot_parallel_tracks():
    """Multiple PRs can be in progress simultaneously on different tracks."""
    state = {
        "feature": "Parallel",
        "completed": ["PR-1"],
        "active": ["PR-2", "PR-5"],
        "blocked": [],
        "prs": [
            {"id": "PR-1", "status": "completed", "dependencies": []},
            {"id": "PR-2", "status": "in_progress", "dependencies": ["PR-1"]},
            {"id": "PR-5", "status": "in_progress", "dependencies": ["PR-1"]},
            {"id": "PR-3", "status": "queued", "dependencies": ["PR-2"]},
        ],
    }

    snapshot = build_vnx_state_snapshot(state, True, ["PR-1", "PR-2", "PR-5", "PR-3"])

    assert snapshot["in_progress"] == ["PR-2", "PR-5"]
    assert snapshot["next_available"] == []


def test_build_snapshot_drops_execution_order_when_unsorted():
    state = {
        "feature": None,
        "completed": [],
        "active": [],
        "blocked": [],
        "prs": [{"id": "PR-1", "status": "queued", "dependencies": []}],
    }

    snapshot = build_vnx_state_snapshot(state, False, ["PR-1"])

    assert snapshot["active_feature"] == {"name": None, "plan_file": None}
    assert snapshot["execution_order"] == []
    assert snapshot["next_available"] == ["PR-1"]
