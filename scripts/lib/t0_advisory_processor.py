#!/usr/bin/env python3
"""T0 quality advisory processor.

Processes completion receipts with quality advisories and makes dispatch decisions.
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class AdvisorySummary:
    """Summary extracted from quality advisory."""
    warning_count: int
    blocking_count: int
    risk_score: int


@dataclass
class T0Recommendation:
    """T0 recommendation from quality advisory."""
    decision: str  # approve | approve_with_followup | hold
    reason: str
    suggested_dispatches: List[Dict[str, Any]]
    open_items: List[Dict[str, Any]]


@dataclass
class QualityAdvisoryData:
    """Parsed quality advisory data."""
    version: str
    generated_at: str
    scope: List[str]
    checks: List[Dict[str, Any]]
    summary: AdvisorySummary
    recommendation: T0Recommendation
    status: str = "available"  # available | unavailable
    error: Optional[str] = None


@dataclass
class TerminalSnapshotData:
    """Parsed terminal snapshot data."""
    timestamp: str
    terminals: Dict[str, Dict[str, Any]]
    status: str = "available"  # available | unavailable
    error: Optional[str] = None


@dataclass
class ProcessedReceipt:
    """Processed completion receipt with parsed advisory data."""
    receipt: Dict[str, Any]
    advisory: Optional[QualityAdvisoryData]
    snapshot: Optional[TerminalSnapshotData]
    is_completion: bool
    has_advisory: bool
    has_snapshot: bool


def is_completion_receipt(receipt: Dict[str, Any]) -> bool:
    """Check if receipt is a completion event."""
    event_type = receipt.get("event_type") or receipt.get("event") or ""
    return event_type in ("task_complete", "task_completed", "completion", "complete")


def parse_quality_advisory(advisory_data: Dict[str, Any]) -> Optional[QualityAdvisoryData]:
    """Parse quality advisory from receipt.

    Args:
        advisory_data: Raw quality_advisory field from receipt

    Returns:
        Parsed QualityAdvisoryData or None if unavailable
    """
    if not advisory_data:
        return None

    # Check if advisory is unavailable
    if advisory_data.get("status") == "unavailable":
        return QualityAdvisoryData(
            version="",
            generated_at="",
            scope=[],
            checks=[],
            summary=AdvisorySummary(0, 0, 0),
            recommendation=T0Recommendation("approve", "Advisory unavailable", [], []),
            status="unavailable",
            error=advisory_data.get("error", "Unknown error"),
        )

    # Parse available advisory
    try:
        summary_data = advisory_data.get("summary", {})
        rec_data = advisory_data.get("t0_recommendation", {})

        summary = AdvisorySummary(
            warning_count=summary_data.get("warning_count", 0),
            blocking_count=summary_data.get("blocking_count", 0),
            risk_score=summary_data.get("risk_score", 0),
        )

        recommendation = T0Recommendation(
            decision=rec_data.get("decision", "approve"),
            reason=rec_data.get("reason", ""),
            suggested_dispatches=rec_data.get("suggested_dispatches", []),
            open_items=rec_data.get("open_items", []),
        )

        return QualityAdvisoryData(
            version=advisory_data.get("version", "1.0"),
            generated_at=advisory_data.get("generated_at", ""),
            scope=advisory_data.get("scope", []),
            checks=advisory_data.get("checks", []),
            summary=summary,
            recommendation=recommendation,
            status="available",
        )
    except (KeyError, TypeError) as exc:
        return QualityAdvisoryData(
            version="",
            generated_at="",
            scope=[],
            checks=[],
            summary=AdvisorySummary(0, 0, 0),
            recommendation=T0Recommendation("approve", f"Parse error: {exc}", [], []),
            status="unavailable",
            error=str(exc),
        )


def parse_terminal_snapshot(snapshot_data: Dict[str, Any]) -> Optional[TerminalSnapshotData]:
    """Parse terminal snapshot from receipt.

    Args:
        snapshot_data: Raw terminal_snapshot field from receipt

    Returns:
        Parsed TerminalSnapshotData or None if unavailable
    """
    if not snapshot_data:
        return None

    # Check if snapshot is unavailable
    if snapshot_data.get("status") == "unavailable":
        return TerminalSnapshotData(
            timestamp="",
            terminals={},
            status="unavailable",
            error=snapshot_data.get("error", "Unknown error"),
        )

    # Parse available snapshot
    try:
        return TerminalSnapshotData(
            timestamp=snapshot_data.get("timestamp", ""),
            terminals=snapshot_data.get("terminals", {}),
            status="available",
        )
    except (KeyError, TypeError) as exc:
        return TerminalSnapshotData(
            timestamp="",
            terminals={},
            status="unavailable",
            error=str(exc),
        )


def process_completion_receipt(receipt: Dict[str, Any]) -> ProcessedReceipt:
    """Process a completion receipt and extract advisory data.

    Args:
        receipt: Raw receipt payload

    Returns:
        ProcessedReceipt with parsed advisory and snapshot data
    """
    is_completion = is_completion_receipt(receipt)

    advisory = None
    snapshot = None
    has_advisory = False
    has_snapshot = False

    if is_completion:
        # Parse quality advisory if present
        if "quality_advisory" in receipt:
            advisory = parse_quality_advisory(receipt["quality_advisory"])
            has_advisory = advisory is not None

        # Parse terminal snapshot if present
        if "terminal_snapshot" in receipt:
            snapshot = parse_terminal_snapshot(receipt["terminal_snapshot"])
            has_snapshot = snapshot is not None

    return ProcessedReceipt(
        receipt=receipt,
        advisory=advisory,
        snapshot=snapshot,
        is_completion=is_completion,
        has_advisory=has_advisory,
        has_snapshot=has_snapshot,
    )


def read_receipts_from_file(receipts_file: Path) -> List[Dict[str, Any]]:
    """Read receipts from NDJSON file.

    Args:
        receipts_file: Path to receipts NDJSON file

    Returns:
        List of receipt payloads
    """
    receipts = []

    if not receipts_file.exists():
        return receipts

    try:
        with open(receipts_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    receipt = json.loads(line)
                    receipts.append(receipt)
                except json.JSONDecodeError:
                    continue
    except OSError:
        pass

    return receipts


def filter_completion_receipts(
    receipts: List[Dict[str, Any]],
    with_advisory: bool = False,
) -> List[ProcessedReceipt]:
    """Filter and process completion receipts.

    Args:
        receipts: List of raw receipts
        with_advisory: If True, only return receipts with quality advisory

    Returns:
        List of processed completion receipts
    """
    processed = []

    for receipt in receipts:
        proc = process_completion_receipt(receipt)

        if not proc.is_completion:
            continue

        if with_advisory and not proc.has_advisory:
            continue

        processed.append(proc)

    return processed


def get_decision_statistics(processed_receipts: List[ProcessedReceipt]) -> Dict[str, int]:
    """Get statistics on T0 decisions.

    Args:
        processed_receipts: List of processed receipts

    Returns:
        Dictionary with decision counts
    """
    stats = {
        "total": len(processed_receipts),
        "approve": 0,
        "approve_with_followup": 0,
        "hold": 0,
        "unavailable": 0,
    }

    for proc in processed_receipts:
        if not proc.advisory:
            continue

        if proc.advisory.status == "unavailable":
            stats["unavailable"] += 1
        else:
            decision = proc.advisory.recommendation.decision
            if decision in stats:
                stats[decision] += 1

    return stats
