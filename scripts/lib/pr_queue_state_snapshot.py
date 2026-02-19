"""Helpers for building PR queue state snapshots."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List


def _next_available_prs(state: Dict[str, Any]) -> List[str]:
    """Return queued PR IDs whose dependencies are satisfied."""
    completed = set(state.get("completed", []))
    next_available: List[str] = []
    for pr in state.get("prs", []):
        if pr.get("status") != "queued":
            continue
        dependencies = pr.get("dependencies", []) or []
        if all(dep in completed for dep in dependencies):
            next_available.append(pr.get("id"))
    return next_available


def build_vnx_state_snapshot(
    state: Dict[str, Any],
    execution_success: bool,
    execution_order: List[str],
) -> Dict[str, Any]:
    """Build the persisted queue snapshot consumed by orchestration helpers."""
    return {
        "active_feature": {
            "name": state.get("feature"),
            "plan_file": "FEATURE_PLAN.md" if state.get("feature") else None,
        },
        "completed_prs": state.get("completed", []),
        "in_progress": state.get("active", []),
        "blocked": state.get("blocked", []),
        "next_available": _next_available_prs(state),
        "execution_order": execution_order if execution_success else [],
        "updated_at": datetime.now().isoformat(),
    }
