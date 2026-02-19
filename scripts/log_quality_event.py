#!/usr/bin/env python3
"""
Quality Gate Intelligence Logger

Logs quality gate verification events to t0_intelligence.ndjson for pattern analysis.

Usage:
    python log_quality_event.py --event-type verification --terminal T1 --reviewer T2 --verdict pass --score 1.0
    python log_quality_event.py --event-type failure --terminal T1 --reviewer T3 --verdict fail --score 0.5 --failures missing_files,fake_tests
    python log_quality_event.py --event-type retry --terminal T1 --reviewer T2 --original-score 0.5 --new-score 1.0 --retry-success true
"""

import argparse
import os
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List
import hashlib


def generate_event_id() -> str:
    """Generate unique event ID"""
    timestamp = datetime.now().isoformat()
    return hashlib.sha256(timestamp.encode()).hexdigest()[:12]


def log_verification_event(
    terminal: str,
    track: str,
    reviewer: str,
    reviewer_track: str,
    task_id: str,
    dispatch_id: str,
    report_path: str,
    exit_code: int,
    verdict: str,
    score: float,
    passed_checks: int,
    failed_checks: int,
    warnings: int,
    evidence_checks: Dict[str, Any],
    shadow_mode: bool = False
) -> Dict[str, Any]:
    """Log quality gate verification event"""

    event = {
        "event_type": "quality_gate_verification" if verdict == "pass" else "quality_gate_failure",
        "timestamp": datetime.utcnow().isoformat() + "Z",  # FIX: Use UTC, not local time
        "event_id": generate_event_id(),

        "terminal": terminal,
        "track": track,
        "reviewer": reviewer,
        "reviewer_track": reviewer_track,

        "task_id": task_id,
        "dispatch_id": dispatch_id,
        "report_path": report_path,

        "verification": {
            "exit_code": exit_code,
            "verdict": verdict,
            "score": score,
            "passed_checks": passed_checks,
            "failed_checks": failed_checks,
            "warnings": warnings
        },

        "evidence_checks": evidence_checks,

        "outcome": "pending",  # Updated by T0 later
        "action_taken": "pending",

        "tags": {
            "issues": [],
            "components": [],
            "quality": []
        },

        "shadow_mode": shadow_mode
    }

    return event


def log_failure_event(
    terminal: str,
    track: str,
    reviewer: str,
    reviewer_track: str,
    task_id: str,
    dispatch_id: str,
    report_path: str,
    exit_code: int,
    verdict: str,
    score: float,
    passed_checks: int,
    failed_checks: int,
    warnings: int,
    evidence_checks: Dict[str, Any],
    failures: List[Dict[str, str]],
    shadow_mode: bool = False
) -> Dict[str, Any]:
    """Log quality gate failure event"""

    event = {
        "event_type": "quality_gate_failure",
        "timestamp": datetime.utcnow().isoformat() + "Z",  # FIX: Use UTC, not local time
        "event_id": generate_event_id(),

        "terminal": terminal,
        "track": track,
        "reviewer": reviewer,
        "reviewer_track": reviewer_track,

        "task_id": task_id,
        "dispatch_id": dispatch_id,
        "report_path": report_path,

        "verification": {
            "exit_code": exit_code,
            "verdict": verdict,
            "score": score,
            "passed_checks": passed_checks,
            "failed_checks": failed_checks,
            "warnings": warnings
        },

        "evidence_checks": evidence_checks,

        "failures": failures,

        "outcome": "pending",
        "action_taken": "pending",
        "correction_dispatch_id": None,

        "tags": {
            "issues": [],
            "components": [],
            "quality": []
        },

        "shadow_mode": shadow_mode
    }

    return event


def log_retry_event(
    terminal: str,
    track: str,
    reviewer: str,
    reviewer_track: str,
    task_id: str,
    original_dispatch_id: str,
    retry_dispatch_id: str,
    report_path: str,
    retry_number: int,
    previous_score: float,
    previous_failures: List[str],
    exit_code: int,
    verdict: str,
    score: float,
    passed_checks: int,
    failed_checks: int,
    warnings: int,
    improvements: List[Dict[str, str]],
    shadow_mode: bool = False
) -> Dict[str, Any]:
    """Log quality gate retry event"""

    event = {
        "event_type": "quality_gate_retry",
        "timestamp": datetime.utcnow().isoformat() + "Z",  # FIX: Use UTC, not local time
        "event_id": generate_event_id(),

        "terminal": terminal,
        "track": track,
        "reviewer": reviewer,
        "reviewer_track": reviewer_track,

        "task_id": task_id,
        "original_dispatch_id": original_dispatch_id,
        "retry_dispatch_id": retry_dispatch_id,
        "report_path": report_path,

        "retry_number": retry_number,
        "previous_score": previous_score,
        "previous_failures": previous_failures,

        "verification": {
            "exit_code": exit_code,
            "verdict": verdict,
            "score": score,
            "passed_checks": passed_checks,
            "failed_checks": failed_checks,
            "warnings": warnings
        },

        "improvements": improvements,

        "outcome": "pending",
        "action_taken": "pending",
        "retry_success": verdict == "pass",

        "tags": {
            "issues": [],
            "components": [],
            "quality": []
        },

        "shadow_mode": shadow_mode
    }

    return event


def append_to_intelligence(event: Dict[str, Any], intelligence_file: Path) -> bool:
    """Append event to t0_intelligence.ndjson"""
    try:
        with open(intelligence_file, 'a') as f:
            f.write(json.dumps(event) + '\n')
        return True
    except Exception as e:
        print(f"❌ Error writing to intelligence file: {e}", file=sys.stderr)
        return False


def update_intelligence_event(event_id: str, updates: Dict[str, Any], intelligence_file: Path) -> bool:
    """Update existing event in t0_intelligence.ndjson (read, modify, rewrite)"""
    try:
        # Read all events
        events = []
        with open(intelligence_file, 'r') as f:
            for line in f:
                event = json.loads(line.strip())
                if event.get("event_id") == event_id:
                    # Update this event
                    event.update(updates)
                events.append(event)

        # Rewrite file
        with open(intelligence_file, 'w') as f:
            for event in events:
                f.write(json.dumps(event) + '\n')

        return True
    except Exception as e:
        print(f"❌ Error updating intelligence event: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(description="Log quality gate events to t0_intelligence.ndjson")

    parser.add_argument("--event-type", required=True, choices=["verification", "failure", "retry"],
                        help="Type of quality gate event")

    # Common arguments
    parser.add_argument("--terminal", required=True, help="Terminal that submitted work (T1, T2, T3)")
    parser.add_argument("--track", required=True, choices=["A", "B", "C"], help="Track of terminal")
    parser.add_argument("--reviewer", required=True, help="Reviewer terminal (T2, T3)")
    parser.add_argument("--reviewer-track", required=True, choices=["A", "B", "C"], help="Reviewer track")
    parser.add_argument("--task-id", required=True, help="Task ID")
    parser.add_argument("--dispatch-id", required=True, help="Dispatch ID")
    parser.add_argument("--report-path", required=True, help="Path to completion report")
    parser.add_argument("--shadow-mode", action="store_true", help="Shadow mode (testing)")

    # Verification arguments
    parser.add_argument("--exit-code", type=int, help="Verification exit code (0=pass, 1=fail)")
    parser.add_argument("--verdict", choices=["pass", "fail"], help="Verification verdict")
    parser.add_argument("--score", type=float, help="Verification score (0.0-1.0)")
    parser.add_argument("--passed-checks", type=int, help="Number of passed checks")
    parser.add_argument("--failed-checks", type=int, help="Number of failed checks")
    parser.add_argument("--warnings", type=int, default=0, help="Number of warnings")

    # Evidence checks (JSON format)
    parser.add_argument("--evidence-checks", help="Evidence checks JSON")

    # Failure-specific
    parser.add_argument("--failures", help="Failure categories (comma-separated)")

    # Retry-specific
    parser.add_argument("--original-dispatch-id", help="Original dispatch ID (for retries)")
    parser.add_argument("--retry-number", type=int, help="Retry number")
    parser.add_argument("--previous-score", type=float, help="Previous verification score")
    parser.add_argument("--previous-failures", help="Previous failures (comma-separated)")
    parser.add_argument("--improvements", help="Improvements JSON")

    # Update mode
    parser.add_argument("--update", help="Update existing event by ID")
    parser.add_argument("--outcome", help="Update outcome (accepted, rejected)")
    parser.add_argument("--action-taken", help="Update action taken")
    parser.add_argument("--correction-dispatch-id", help="Correction dispatch ID")

    args = parser.parse_args()

    # Resolve VNX paths
    vnx_home = Path(os.environ.get("VNX_HOME") or Path(__file__).resolve().parents[1])
    intelligence_file = Path(os.environ.get("VNX_STATE_DIR") or (vnx_home / "state")) / "t0_intelligence.ndjson"

    # Update mode
    if args.update:
        updates = {}
        if args.outcome:
            updates["outcome"] = args.outcome
        if args.action_taken:
            updates["action_taken"] = args.action_taken
        if args.correction_dispatch_id:
            updates["correction_dispatch_id"] = args.correction_dispatch_id

        success = update_intelligence_event(args.update, updates, intelligence_file)
        if success:
            print(f"✅ Updated event {args.update}")
        sys.exit(0 if success else 1)

    # Parse evidence checks
    evidence_checks = {}
    if args.evidence_checks:
        try:
            evidence_checks = json.loads(args.evidence_checks)
        except json.JSONDecodeError:
            print(f"❌ Invalid evidence checks JSON", file=sys.stderr)
            sys.exit(1)

    # Create event based on type
    if args.event_type == "verification":
        event = log_verification_event(
            terminal=args.terminal,
            track=args.track,
            reviewer=args.reviewer,
            reviewer_track=args.reviewer_track,
            task_id=args.task_id,
            dispatch_id=args.dispatch_id,
            report_path=args.report_path,
            exit_code=args.exit_code,
            verdict=args.verdict,
            score=args.score,
            passed_checks=args.passed_checks,
            failed_checks=args.failed_checks,
            warnings=args.warnings,
            evidence_checks=evidence_checks,
            shadow_mode=args.shadow_mode
        )

    elif args.event_type == "failure":
        failures = []
        if args.failures:
            for category in args.failures.split(','):
                failures.append({
                    "category": category.strip(),
                    "severity": "high",  # Can be enhanced later
                    "details": "",
                    "fix_required": ""
                })

        event = log_failure_event(
            terminal=args.terminal,
            track=args.track,
            reviewer=args.reviewer,
            reviewer_track=args.reviewer_track,
            task_id=args.task_id,
            dispatch_id=args.dispatch_id,
            report_path=args.report_path,
            exit_code=args.exit_code,
            verdict=args.verdict,
            score=args.score,
            passed_checks=args.passed_checks,
            failed_checks=args.failed_checks,
            warnings=args.warnings,
            evidence_checks=evidence_checks,
            failures=failures,
            shadow_mode=args.shadow_mode
        )

    elif args.event_type == "retry":
        improvements = []
        if args.improvements:
            try:
                improvements = json.loads(args.improvements)
            except json.JSONDecodeError:
                print(f"❌ Invalid improvements JSON", file=sys.stderr)
                sys.exit(1)

        previous_failures = []
        if args.previous_failures:
            previous_failures = [f.strip() for f in args.previous_failures.split(',')]

        event = log_retry_event(
            terminal=args.terminal,
            track=args.track,
            reviewer=args.reviewer,
            reviewer_track=args.reviewer_track,
            task_id=args.task_id,
            original_dispatch_id=args.original_dispatch_id,
            retry_dispatch_id=args.dispatch_id,
            report_path=args.report_path,
            retry_number=args.retry_number,
            previous_score=args.previous_score,
            previous_failures=previous_failures,
            exit_code=args.exit_code,
            verdict=args.verdict,
            score=args.score,
            passed_checks=args.passed_checks,
            failed_checks=args.failed_checks,
            warnings=args.warnings,
            improvements=improvements,
            shadow_mode=args.shadow_mode
        )

    # Append to intelligence file
    success = append_to_intelligence(event, intelligence_file)

    if success:
        print(f"✅ Logged {args.event_type} event: {event['event_id']}")
        print(f"   Event ID: {event['event_id']}")
        print(f"   Terminal: {args.terminal} (Track {args.track})")
        print(f"   Reviewer: {args.reviewer} (Track {args.reviewer_track})")
        print(f"   Verdict: {args.verdict} ({args.score:.2f})")
    else:
        print(f"❌ Failed to log {args.event_type} event", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
