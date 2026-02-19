#!/usr/bin/env python3
"""Tests for canonical state projections used by dashboard/brief/notifier."""

from __future__ import annotations

import json
import sys
from pathlib import Path

SCRIPTS_LIB = Path(__file__).resolve().parents[1] / "scripts" / "lib"
if str(SCRIPTS_LIB) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_LIB))

import canonical_state_views as views  # noqa: E402


def test_notifier_enrichment_uses_terminal_state_as_primary(tmp_path: Path):
    terminal_state = {
        "schema_version": 1,
        "terminals": {
            "T1": {
                "terminal_id": "T1",
                "status": "claimed",
                "claimed_by": "dispatch-A",
                "claimed_at": "2026-02-10T12:00:00+00:00",
                "lease_expires_at": "2026-02-10T12:01:00+00:00",
                "last_activity": "2026-02-10T12:00:10+00:00",
                "version": 1,
            },
            "T2": {
                "terminal_id": "T2",
                "status": "idle",
                "claimed_by": None,
                "claimed_at": None,
                "lease_expires_at": None,
                "last_activity": "2026-02-10T12:00:12+00:00",
                "version": 1,
            },
            "T3": {
                "terminal_id": "T3",
                "status": "blocked",
                "claimed_by": None,
                "claimed_at": None,
                "lease_expires_at": None,
                "last_activity": "2026-02-10T12:00:13+00:00",
                "version": 1,
            },
        },
    }
    (tmp_path / "terminal_state.json").write_text(json.dumps(terminal_state), encoding="utf-8")

    brief = {
        "terminals": {
            "T1": {"status": "offline"},
            "T2": {"status": "offline"},
            "T3": {"status": "offline"},
        },
        "queues": {"pending": 4, "active": 1},
        "next_gates": {"A": "review", "B": "testing", "C": "integration"},
        "recommendations": [{"trigger": "pr_ready", "action": "dispatch"}],
    }
    (tmp_path / "t0_brief.json").write_text(json.dumps(brief), encoding="utf-8")

    payload = views.build_notifier_system_state(tmp_path)
    assert payload["terminals"]["T1"]["status"] == "working"
    assert payload["terminals"]["T1"]["current_task"] == "dispatch-A"
    assert payload["terminals"]["T2"]["status"] == "idle"
    assert payload["terminals"]["T3"]["status"] == "blocked"
    assert payload["queues"]["pending"] == 4
    assert payload["next_gates"]["A"] == "review"
    assert payload["recommendations"][0]["trigger"] == "pr_ready"


def test_notifier_enrichment_falls_back_to_brief_when_primary_missing(tmp_path: Path):
    brief = {
        "terminals": {
            "T1": {"status": "working", "current_task": "dispatch-brief-A"},
            "T2": {"status": "idle"},
            "T3": {"status": "blocked"},
        },
        "queues": {"pending": 2, "active": 0},
        "next_gates": {"A": "implementation", "B": "review", "C": "testing"},
        "recommendations": [{"trigger": "pr_blocked", "action": "unblock"}],
    }
    (tmp_path / "t0_brief.json").write_text(json.dumps(brief), encoding="utf-8")

    payload = views.build_notifier_system_state(tmp_path)
    assert payload["terminals"]["T1"]["status"] == "working"
    assert payload["terminals"]["T1"]["current_task"] == "dispatch-brief-A"
    assert payload["terminals"]["T2"]["status"] == "idle"
    assert payload["terminals"]["T3"]["status"] == "blocked"
    assert payload["queues"]["pending"] == 2
    assert payload["next_gates"]["C"] == "testing"
    assert payload["recommendations"][0]["trigger"] == "pr_blocked"


def test_dashboard_terminals_override_stale_records(tmp_path: Path):
    terminal_state = {
        "schema_version": 1,
        "terminals": {
            "T1": {
                "terminal_id": "T1",
                "status": "idle",
                "claimed_by": None,
                "claimed_at": None,
                "lease_expires_at": None,
                "last_activity": "2026-02-10T12:00:10+00:00",
                "version": 1,
            },
            "T2": {
                "terminal_id": "T2",
                "status": "working",
                "claimed_by": "dispatch-B",
                "claimed_at": "2026-02-10T12:00:20+00:00",
                "lease_expires_at": "2026-02-10T12:05:20+00:00",
                "last_activity": "2026-02-10T12:00:20+00:00",
                "version": 1,
            },
            "T3": {
                "terminal_id": "T3",
                "status": "idle",
                "claimed_by": None,
                "claimed_at": None,
                "lease_expires_at": None,
                "last_activity": "2026-02-10T12:00:00+00:00",
                "version": 1,
            },
        },
    }
    (tmp_path / "terminal_state.json").write_text(json.dumps(terminal_state), encoding="utf-8")

    receipts = [
        {
            "timestamp": "2026-02-10T12:10:00+00:00",
            "event_type": "task_started",
            "status": "confirmed",
            "terminal": "T3",
            "dispatch_id": "dispatch-C",
        }
    ]
    receipts_path = tmp_path / "t0_receipts.ndjson"
    receipts_path.write_text("\n".join(json.dumps(item) for item in receipts) + "\n", encoding="utf-8")

    snapshot = views.build_terminal_snapshot(
        tmp_path,
        stale_after_seconds=180,
        allow_tmux_probe=False,
    )
    assert snapshot["terminals"]["T3"]["status"] == "working"


def test_dashboard_terminals_do_not_promote_stale_idle_without_claim_signal(tmp_path: Path, monkeypatch):
    terminal_state = {
        "schema_version": 1,
        "terminals": {
            "T1": {
                "terminal_id": "T1",
                "status": "idle",
                "claimed_by": None,
                "claimed_at": None,
                "lease_expires_at": None,
                "last_activity": "2026-02-10T12:00:10+00:00",
                "version": 1,
            },
            "T2": {
                "terminal_id": "T2",
                "status": "idle",
                "claimed_by": None,
                "claimed_at": None,
                "lease_expires_at": None,
                "last_activity": "2026-02-10T12:00:10+00:00",
                "version": 1,
            },
            "T3": {
                "terminal_id": "T3",
                "status": "idle",
                "claimed_by": None,
                "claimed_at": None,
                "lease_expires_at": None,
                "last_activity": "2026-02-10T12:00:00+00:00",
                "version": 1,
            },
        },
    }
    (tmp_path / "terminal_state.json").write_text(json.dumps(terminal_state), encoding="utf-8")

    def _fake_reconcile(*_args, **_kwargs):
        return {
            "terminals": {
                "T3": {
                    "terminal_id": "T3",
                    "status": "active",
                    "claimed_by": None,
                    "claimed_at": None,
                    "lease_expires_at": None,
                    "last_activity": "2026-02-10T12:10:00+00:00",
                    "reconciled_source": "fallback",
                }
            },
            "evidence": {"tmux": {}},
            "degraded": False,
            "degraded_reasons": [],
        }

    monkeypatch.setattr(views, "reconcile_terminal_state", _fake_reconcile)
    snapshot = views.build_terminal_snapshot(tmp_path, stale_after_seconds=180, allow_tmux_probe=True)
    assert snapshot["terminals"]["T3"]["status"] == "idle"


def test_dashboard_terminals_reconciler_working_without_claim_is_demoted(tmp_path: Path, monkeypatch):
    def _fake_reconcile(*_args, **_kwargs):
        return {
            "terminals": {
                "T3": {
                    "terminal_id": "T3",
                    "status": "working",
                    "claimed_by": None,
                    "claimed_at": None,
                    "lease_expires_at": None,
                    "last_activity": "2026-02-10T12:10:00+00:00",
                    "reconciled_source": "fallback",
                }
            },
            "evidence": {"tmux": {"T3": {"current_command": "node"}}},
            "degraded": True,
            "degraded_reasons": ["primary_stale"],
        }

    monkeypatch.setattr(views, "reconcile_terminal_state", _fake_reconcile)
    snapshot = views.build_terminal_snapshot(tmp_path, stale_after_seconds=180, allow_tmux_probe=True)
    assert snapshot["source"] == "reconciler"
    assert snapshot["terminals"]["T3"]["status"] == "idle"
