#!/usr/bin/env python3
"""Regression tests for intelligence daemon canonical path behavior."""

import importlib
import json
import sys
import types
from datetime import datetime
from pathlib import Path


SCRIPTS_DIR = Path(__file__).parent.parent / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))


def _install_stub_modules():
    gather_mod = types.ModuleType("gather_intelligence")
    learning_mod = types.ModuleType("learning_loop")
    cached_mod = types.ModuleType("cached_intelligence")

    class DummyGatherer:
        def __init__(self):
            self.quality_db = None

    class DummyLearningLoop:
        def daily_learning_cycle(self):
            return {"statistics": {}, "pattern_metrics": {}}

    class DummyCachedIntelligence:
        def update_pattern_rankings(self):
            return None

    gather_mod.T0IntelligenceGatherer = DummyGatherer
    learning_mod.LearningLoop = DummyLearningLoop
    cached_mod.CachedIntelligence = DummyCachedIntelligence

    sys.modules["gather_intelligence"] = gather_mod
    sys.modules["learning_loop"] = learning_mod
    sys.modules["cached_intelligence"] = cached_mod


def _load_daemon_module():
    _install_stub_modules()
    module = importlib.import_module("intelligence_daemon")
    return importlib.reload(module)


def test_intelligence_health_writes_canonical_only_by_default(tmp_path, monkeypatch):
    vnx_home = tmp_path / "vnx-home"
    state_dir = tmp_path / "data" / "state"
    vnx_home.mkdir(parents=True, exist_ok=True)
    state_dir.mkdir(parents=True, exist_ok=True)

    monkeypatch.setenv("VNX_HOME", str(vnx_home))
    monkeypatch.setenv("VNX_DATA_DIR", str(tmp_path / "data"))
    monkeypatch.setenv("VNX_STATE_DIR", str(state_dir))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))

    daemon_mod = _load_daemon_module()
    daemon = daemon_mod.IntelligenceDaemon()
    daemon.health_status["patterns_available"] = 9
    daemon.health_status["status"] = "healthy"
    daemon.write_intelligence_health()

    canonical = state_dir / "intelligence_health.json"
    legacy = vnx_home / "state" / "intelligence_health.json"

    assert canonical.exists()
    assert not legacy.exists()

    first_payload = json.loads(canonical.read_text(encoding="utf-8"))
    first_ts = datetime.fromisoformat(first_payload["timestamp"])
    assert first_payload["patterns_available"] == 9

    daemon.health_status["patterns_available"] = 11
    daemon.write_intelligence_health()
    second_payload = json.loads(canonical.read_text(encoding="utf-8"))
    second_ts = datetime.fromisoformat(second_payload["timestamp"])

    assert second_payload["patterns_available"] == 11
    assert second_ts >= first_ts


def test_intelligence_health_mirrors_legacy_in_rollback_mode(tmp_path, monkeypatch):
    vnx_home = tmp_path / "vnx-home"
    state_dir = tmp_path / "data" / "state"
    vnx_home.mkdir(parents=True, exist_ok=True)
    state_dir.mkdir(parents=True, exist_ok=True)

    monkeypatch.setenv("VNX_HOME", str(vnx_home))
    monkeypatch.setenv("VNX_DATA_DIR", str(tmp_path / "data"))
    monkeypatch.setenv("VNX_STATE_DIR", str(state_dir))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("VNX_STATE_SIMPLIFICATION_ROLLBACK", "1")

    daemon_mod = _load_daemon_module()
    daemon = daemon_mod.IntelligenceDaemon()
    daemon.health_status["patterns_available"] = 5
    daemon.health_status["status"] = "healthy"
    daemon.write_intelligence_health()

    canonical = state_dir / "intelligence_health.json"
    legacy = vnx_home / "state" / "intelligence_health.json"

    assert canonical.exists()
    assert legacy.exists()


def test_dashboard_sync_write_is_opt_in_for_single_writer(tmp_path, monkeypatch):
    vnx_home = tmp_path / "vnx-home"
    canonical_state = tmp_path / "data" / "state"
    legacy_state = vnx_home / "state"
    vnx_home.mkdir(parents=True, exist_ok=True)
    canonical_state.mkdir(parents=True, exist_ok=True)
    legacy_state.mkdir(parents=True, exist_ok=True)

    monkeypatch.setenv("VNX_HOME", str(vnx_home))
    monkeypatch.setenv("VNX_DATA_DIR", str(tmp_path / "data"))
    monkeypatch.setenv("VNX_STATE_DIR", str(canonical_state))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))

    brief = {
        "terminals": {"T1": {"status": "working", "track": "A", "current_task": "task-A", "ready": True}},
        "tracks": {"A": {"current_gate": "gate_pr1_init", "status": "working"}},
        "recent_receipts": [],
        "queues": {},
    }
    (canonical_state / "t0_brief.json").write_text(json.dumps(brief), encoding="utf-8")

    dashboard = canonical_state / "dashboard_status.json"
    daemon_mod = _load_daemon_module()
    daemon = daemon_mod.IntelligenceDaemon()
    daemon.health_status["status"] = "healthy"
    daemon.write_health_status()
    assert not dashboard.exists()

    monkeypatch.setenv("VNX_INTELLIGENCE_DASHBOARD_WRITE", "1")
    daemon_mod = _load_daemon_module()
    daemon = daemon_mod.IntelligenceDaemon()
    daemon.health_status["status"] = "healthy"
    daemon.write_health_status()

    assert dashboard.exists()
    payload = json.loads(dashboard.read_text(encoding="utf-8"))
    assert payload.get("pr_queue", {}).get("total_prs", 0) >= 1
    assert payload.get("intelligence_daemon", {}).get("status") == "healthy"


def test_dashboard_reads_legacy_brief_only_in_rollback_mode(tmp_path, monkeypatch):
    vnx_home = tmp_path / "vnx-home"
    canonical_state = tmp_path / "data" / "state"
    legacy_state = vnx_home / "state"
    vnx_home.mkdir(parents=True, exist_ok=True)
    canonical_state.mkdir(parents=True, exist_ok=True)
    legacy_state.mkdir(parents=True, exist_ok=True)

    monkeypatch.setenv("VNX_HOME", str(vnx_home))
    monkeypatch.setenv("VNX_DATA_DIR", str(tmp_path / "data"))
    monkeypatch.setenv("VNX_STATE_DIR", str(canonical_state))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("VNX_INTELLIGENCE_DASHBOARD_WRITE", "1")
    monkeypatch.setenv("VNX_STATE_SIMPLIFICATION_ROLLBACK", "1")

    brief = {
        "terminals": {"T1": {"status": "working", "track": "A", "current_task": "task-legacy", "ready": True}},
        "tracks": {"A": {"current_gate": "gate_pr1_init", "status": "working"}},
        "recent_receipts": [],
        "queues": {},
    }
    (legacy_state / "t0_brief.json").write_text(json.dumps(brief), encoding="utf-8")

    daemon_mod = _load_daemon_module()
    daemon = daemon_mod.IntelligenceDaemon()
    daemon.health_status["status"] = "healthy"
    daemon.write_health_status()

    payload = json.loads((canonical_state / "dashboard_status.json").read_text(encoding="utf-8"))
    assert payload.get("pr_queue", {}).get("total_prs", 0) >= 1
