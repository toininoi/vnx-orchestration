#!/usr/bin/env python3
"""AS-07 regression tests for intelligence monitor schema compatibility."""

from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import intelligence_daemon_monitor as monitor


def _paths(tmp_path: Path) -> dict[str, str]:
    state_dir = tmp_path / "state"
    pids_dir = tmp_path / "pids"
    state_dir.mkdir(parents=True, exist_ok=True)
    pids_dir.mkdir(parents=True, exist_ok=True)
    return {"VNX_STATE_DIR": str(state_dir), "VNX_PIDS_DIR": str(pids_dir)}


def _db_path(paths: dict[str, str]) -> Path:
    return Path(paths["VNX_STATE_DIR"]) / "quality_intelligence.db"


def _create_compatible_schema(db_path: Path) -> None:
    conn = sqlite3.connect(str(db_path))
    try:
        conn.execute(
            """
            CREATE TABLE code_snippets (
                quality_score REAL,
                last_updated TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE success_patterns (
                confidence_score REAL,
                first_seen TEXT,
                last_used TEXT
            )
            """
        )
        conn.executemany(
            "INSERT INTO code_snippets (quality_score, last_updated) VALUES (?, ?)",
            [
                (91.0, "2026-02-11T08:00:00"),
                (70.0, "2026-02-11T08:30:00"),
                (84.0, "2026-02-11T09:00:00"),
            ],
        )
        conn.executemany(
            """
            INSERT INTO success_patterns (confidence_score, first_seen, last_used)
            VALUES (?, ?, ?)
            """,
            [
                (0.9, "2026-02-11T09:30:00", "2026-02-11T10:00:00"),
                (0.5, "2026-02-11T07:00:00", "2026-02-11T07:30:00"),
            ],
        )
        conn.commit()
    finally:
        conn.close()


def test_schema_compatibility_success_and_monitor_queries(tmp_path: Path):
    paths = _paths(tmp_path)
    db_path = _db_path(paths)
    _create_compatible_schema(db_path)

    monitor.run_startup_schema_check(paths)
    status = monitor.get_intelligence_daemon_status(paths)

    assert status["status"] == "offline"
    assert status["patterns_available"] == 3
    assert status["last_extraction"] == "2026-02-11T10:00:00"


def test_schema_compatibility_failure_missing_required_table(tmp_path: Path):
    paths = _paths(tmp_path)
    db_path = _db_path(paths)
    conn = sqlite3.connect(str(db_path))
    try:
        conn.execute(
            """
            CREATE TABLE code_snippets (
                quality_score REAL,
                last_updated TEXT
            )
            """
        )
        conn.commit()
    finally:
        conn.close()

    with pytest.raises(monitor.SchemaCompatibilityError, match="success_patterns"):
        monitor.run_startup_schema_check(paths)


def test_schema_compatibility_failure_is_not_swallowed(tmp_path: Path):
    paths = _paths(tmp_path)
    db_path = _db_path(paths)
    conn = sqlite3.connect(str(db_path))
    try:
        conn.execute(
            """
            CREATE TABLE code_snippets (
                quality_score REAL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE success_patterns (
                confidence_score REAL,
                first_seen TEXT,
                last_used TEXT
            )
            """
        )
        conn.commit()
    finally:
        conn.close()

    with pytest.raises(monitor.SchemaCompatibilityError, match="code_snippets"):
        monitor.get_intelligence_daemon_status(paths)
