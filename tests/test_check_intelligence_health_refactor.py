#!/usr/bin/env python3
"""Unit tests for check_intelligence_health helper extractions (AS-05)."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys

SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import check_intelligence_health as health_mod


def test_determine_health_status_thresholds():
    assert health_mod._determine_health_status(True, True, 3, 81.0) == "healthy"
    assert health_mod._determine_health_status(True, True, 3, 55.0) == "degraded"
    assert health_mod._determine_health_status(True, True, 3, 30.0) == "unhealthy"
    assert health_mod._determine_health_status(False, True, 3, 95.0) == "unhealthy"
    assert health_mod._determine_health_status(True, False, 3, 95.0) == "unhealthy"
    assert health_mod._determine_health_status(True, True, 0, 95.0) == "unhealthy"


def test_collect_receipt_coverage_tracks_warnings(tmp_path: Path):
    receipts = tmp_path / "t0_receipts.ndjson"
    receipts.write_text(
        "\n".join(
            [
                json.dumps({"quality_context": {"a": 1}, "pattern_count": 2}),
                json.dumps({"quality_context": {}, "pattern_count": "bad"}),
                "{not-json}",
            ]
        ),
        encoding="utf-8",
    )

    warnings: list[str] = []
    with_intel, total, with_patterns, coverage = health_mod._collect_receipt_coverage(receipts, warnings)

    assert with_intel == 1
    assert total == 2
    assert with_patterns == 1
    assert coverage == 50.0
    assert "receipt_parse_failed" in warnings
    assert "receipt_pattern_count_invalid" in warnings


def test_enrich_from_intelligence_file_sets_recent_and_pattern_count(tmp_path: Path):
    intelligence_file = tmp_path / "t0_intelligence.ndjson"
    now = datetime.now(timezone.utc)
    intelligence_file.write_text(
        json.dumps({"timestamp": now.isoformat(), "pattern_count": 7}),
        encoding="utf-8",
    )

    health = {"patterns_available": 0}
    warnings: list[str] = []
    recent, last_time = health_mod._enrich_from_intelligence_file(intelligence_file, health, warnings)

    assert recent is True
    assert last_time is not None
    assert health["patterns_available"] == 7
    assert warnings == []


def test_load_base_health_marks_stale_and_falls_back(tmp_path: Path, monkeypatch):
    health_file = tmp_path / "intelligence_health.json"
    stale_timestamp = (datetime.now(timezone.utc) - timedelta(minutes=3)).isoformat()
    health_file.write_text(
        json.dumps(
            {
                "daemon_running": False,
                "daemon_pid": None,
                "patterns_available": 9,
                "last_extraction": "yesterday",
                "timestamp": stale_timestamp,
            }
        ),
        encoding="utf-8",
    )

    monkeypatch.setattr(health_mod, "_fallback_daemon_status", lambda warnings: (True, "9999"))
    warnings: list[str] = []
    daemon_running, daemon_pid, pattern_count, last_extraction = health_mod._load_base_health(health_file, warnings)

    assert daemon_running is True
    assert daemon_pid == "9999"
    assert pattern_count == 9
    assert last_extraction == "yesterday"
    assert "health_file_stale" in warnings
