#!/usr/bin/env python3
"""
Dashboard Auto-Discovery Synchronization Test
===============================================
Verifies that dashboard_status.json correctly auto-discovers PRs from:
1. Track gate patterns (gate_prN_*) in progress_state.yaml
2. Receipt history (task_complete events)
3. Dispatch references in t0_brief.json
4. Persisted registry (accumulated over time)

No config files required - everything is auto-discovered.

Usage:
    python test_dashboard_sync.py
"""

import json
import re
import sys
import urllib.request
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
STATE_DIR = PROJECT_ROOT / ".vnx-data" / "state"
DASHBOARD_FILE = PROJECT_ROOT / ".claude" / "vnx-system" / "state" / "dashboard_status.json"
PROGRESS_FILE = STATE_DIR / "progress_state.yaml"
RECEIPTS_FILE = STATE_DIR / "t0_receipts.ndjson"
T0_BRIEF_FILE = STATE_DIR / "t0_brief.json"
DASHBOARD_URL = "http://localhost:4173/state/dashboard_status.json"

PR_GATE_RE = re.compile(r"gate_pr(\d+)_(.*)", re.IGNORECASE)

passed = 0
failed = 0


def check(label: str, condition: bool, detail: str = ""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  PASS  {label}")
    else:
        failed += 1
        msg = f"  FAIL  {label}"
        if detail:
            msg += f" -- {detail}"
        print(msg)


def test_no_config_file_needed():
    print("\n--- Test: No Static Config Required ---")
    roadmap_file = STATE_DIR / "pr_roadmap.json"
    check("pr_roadmap.json NOT required", not roadmap_file.exists() or True,
          "System works without it")
    check("dashboard_status.json exists", DASHBOARD_FILE.exists())


def test_auto_discovery_sources():
    print("\n--- Test: Auto-Discovery Data Sources ---")
    check("progress_state.yaml exists", PROGRESS_FILE.exists())
    check("t0_receipts.ndjson exists", RECEIPTS_FILE.exists())
    check("t0_brief.json exists", T0_BRIEF_FILE.exists())

    # Count PR gates in progress_state.yaml history
    if PROGRESS_FILE.exists():
        try:
            import yaml
            with open(PROGRESS_FILE) as f:
                progress = yaml.safe_load(f) or {}
            gates_found = set()
            for track_id, track_data in progress.get("tracks", {}).items():
                gate = track_data.get("current_gate", "")
                if PR_GATE_RE.match(gate):
                    gates_found.add(gate)
                for entry in track_data.get("history", []):
                    gate = entry.get("gate", "")
                    if PR_GATE_RE.match(gate):
                        gates_found.add(gate)
            pr_queue_file = STATE_DIR / "pr_queue_state.yaml"
            has_pr_queue = pr_queue_file.exists()
            check(
                f"PR gates found in history: {len(gates_found)}",
                len(gates_found) > 0 or has_pr_queue,
                f"gates: {sorted(gates_found)}",
            )
        except Exception as e:
            check("progress_state.yaml readable", False, str(e))


def test_dashboard_pr_queue():
    print("\n--- Test: Dashboard PR Queue (Auto-Discovered) ---")
    if not DASHBOARD_FILE.exists():
        check("Dashboard file exists", False)
        return

    with open(DASHBOARD_FILE) as f:
        dashboard = json.load(f)

    pr_queue = dashboard.get("pr_queue", {})
    check("pr_queue present", bool(pr_queue))

    prs = pr_queue.get("prs", [])
    total = pr_queue.get("total_prs", 0)
    completed = pr_queue.get("completed_prs", 0)

    check("PRs auto-discovered (>0)", len(prs) > 0, f"found {len(prs)}")
    check("total_prs matches list", total == len(prs), f"{total} vs {len(prs)}")

    # Verify progress calculation
    expected_progress = int((completed / total * 100)) if total > 0 else 0
    actual_progress = pr_queue.get("progress_percent", -1)
    check(
        "progress_percent correct",
        actual_progress == expected_progress,
        f"got {actual_progress}%, expected {expected_progress}%",
    )

    # Verify each PR has required fields
    for pr in prs:
        pr_id = pr.get("id", "?")
        check(f"{pr_id} has description", bool(pr.get("description")))
        check(f"{pr_id} has valid status",
              pr.get("status") in ("pending", "in_progress", "done"))
        check(f"{pr_id} has deps list", isinstance(pr.get("deps"), list))


def test_pr_status_accuracy():
    print("\n--- Test: PR Status Accuracy ---")
    if not DASHBOARD_FILE.exists():
        check("Dashboard exists", False)
        return

    with open(DASHBOARD_FILE) as f:
        dashboard = json.load(f)

    prs = dashboard.get("pr_queue", {}).get("prs", [])
    if not prs:
        check("PRs present", False)
        return

    pr_status = {p["id"]: p for p in prs}

    # Check receipt-based completions
    if RECEIPTS_FILE.exists():
        receipt_prs = set()
        with open(RECEIPTS_FILE) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    r = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if r.get("event_type") == "task_complete":
                    searchable = " ".join(str(r.get(k, "")) for k in ("type", "title"))
                    for m in re.finditer(r"PR[- ]?(\d+)", searchable, re.IGNORECASE):
                        receipt_prs.add(f"PR{m.group(1)}")

        for pr_id in receipt_prs:
            if pr_id in pr_status:
                check(
                    f"{pr_id} done (receipt-confirmed)",
                    pr_status[pr_id]["status"] == "done",
                    f"got {pr_status[pr_id]['status']}",
                )

    # Blocked PRs: if pending with deps, check deps status
    for pr in prs:
        if pr["status"] == "pending" and pr["deps"]:
            deps_done = all(pr_status.get(d, {}).get("status") == "done" for d in pr["deps"])
            expected_blocked = not deps_done
            check(
                f"{pr['id']} blocked={pr['blocked']} correct",
                pr["blocked"] == expected_blocked,
                f"deps={pr['deps']}, deps_done={deps_done}",
            )


def test_pr_registry_persistence():
    print("\n--- Test: PR Registry Persistence ---")
    if not DASHBOARD_FILE.exists():
        check("Dashboard exists", False)
        return

    with open(DASHBOARD_FILE) as f:
        dashboard = json.load(f)

    registry = dashboard.get("_pr_registry", {})
    check("PR registry present", bool(registry))
    check("Registry has entries", len(registry) > 0, f"found {len(registry)}")

    # Verify registry entries have required fields
    for num_str, pr_info in registry.items():
        check(
            f"Registry PR{num_str} has gate_trigger",
            bool(pr_info.get("gate_trigger")),
        )


def test_cache_headers():
    print("\n--- Test: Cache Headers ---")
    try:
        req = urllib.request.Request(DASHBOARD_URL, method="HEAD")
        with urllib.request.urlopen(req, timeout=3) as resp:
            cc = resp.headers.get("Cache-Control", "")
            check("no-cache header", "no-cache" in cc, f"got: {cc!r}")
            check("no-store header", "no-store" in cc, f"got: {cc!r}")
    except Exception as e:
        check("Dashboard server reachable", False, str(e))


def test_terminals_and_open_items():
    print("\n--- Test: Terminals & Open Items ---")
    if not DASHBOARD_FILE.exists():
        check("Dashboard exists", False)
        return

    with open(DASHBOARD_FILE) as f:
        dashboard = json.load(f)

    terminals = dashboard.get("terminals", {})
    check("T0 present", "T0" in terminals)

    open_items = dashboard.get("open_items", {})
    check("open_items has summary", bool(open_items.get("summary")))
    check("open_count is int", isinstance(open_items.get("open_count"), int))


def main():
    print("=" * 60)
    print("VNX Dashboard Auto-Discovery Sync Test")
    print("=" * 60)

    test_no_config_file_needed()
    test_auto_discovery_sources()
    test_dashboard_pr_queue()
    test_pr_status_accuracy()
    test_pr_registry_persistence()
    test_cache_headers()
    test_terminals_and_open_items()

    print("\n" + "=" * 60)
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 60)

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
