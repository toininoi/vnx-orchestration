#!/usr/bin/env python3
"""
Quality Digest Builder for T0 Intelligence System
Purpose: Generate actionable quality digest from quality_intelligence.db
Output: t0_quality_digest.json with top hotspots and track routing hints
"""

import json
import sqlite3
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Any, Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))
try:
    from vnx_paths import ensure_env
except Exception as exc:
    raise SystemExit(f"Failed to load vnx_paths: {exc}")

PATHS = ensure_env()
STATE_DIR = Path(PATHS["VNX_STATE_DIR"])
QUALITY_DB = STATE_DIR / "quality_intelligence.db"
OUTPUT_FILE = STATE_DIR / "t0_quality_digest.json"

# quality_intelligence.db schema source-of-truth:
# - vnx_code_quality table (file-level metrics)
# - files_needing_attention view (critical/hotspot subset)

def query_quality_metrics(db_path: Path, limit: int = 20) -> List[Dict[str, Any]]:
    """
    Query quality database for top complexity hotspots.
    """
    if not db_path.exists():
        logger.warning(f"Quality database not found: {db_path}")
        return []

    hotspots = []

    try:
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()

        query = """
        SELECT
            q.file_path,
            q.complexity_score,
            q.cyclomatic_complexity,
            q.cognitive_complexity,
            q.max_nesting_depth,
            q.max_function_length,
            q.critical_issues,
            q.warning_issues,
            q.info_issues,
            q.suggested_track,
            q.track_confidence,
            q.last_scan
        FROM vnx_code_quality q
        WHERE q.file_path IN (
            SELECT file_path
            FROM files_needing_attention
        )
        ORDER BY q.complexity_score DESC
        LIMIT ?
        """

        cursor.execute(query, (limit,))

        for (
            file_path,
            complexity_score,
            cyclomatic_complexity,
            cognitive_complexity,
            max_nesting_depth,
            max_function_length,
            critical_issues,
            warning_issues,
            info_issues,
            suggested_track,
            track_confidence,
            last_scan,
        ) in cursor.fetchall():
            complexity = float(complexity_score or 0)
            if complexity >= 90:
                severity = "critical"
            elif complexity >= 75:
                severity = "high"
            elif complexity >= 50:
                severity = "medium"
            else:
                severity = "low"

            hotspots.append(
                {
                    "file": file_path,
                    "complexity": round(complexity, 2),
                    "cyclomatic_complexity": cyclomatic_complexity,
                    "cognitive_complexity": cognitive_complexity,
                    "max_nesting_depth": max_nesting_depth,
                    "max_function_length": max_function_length,
                    "critical_issues": int(critical_issues or 0),
                    "warning_issues": int(warning_issues or 0),
                    "info_issues": int(info_issues or 0),
                    "suggested_track": suggested_track or "C",
                    "track_confidence": round(float(track_confidence or 0), 2),
                    "severity": severity,
                    "last_scan": last_scan,
                }
            )

        conn.close()

    except sqlite3.Error as e:
        logger.error(f"Database error: {e}")
    except Exception as e:
        logger.error(f"Unexpected error querying database: {e}")

    return hotspots

def query_recent_issues(db_path: Path, days: int = 7) -> List[Dict[str, Any]]:
    """
    Query recent quality issues for trend analysis.
    """
    if not db_path.exists():
        return []

    recent_issues = []

    try:
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()

        # Get recently-scanned files that still have issues.
        query = """
        SELECT
            file_path,
            complexity_score,
            critical_issues,
            warning_issues,
            suggested_track,
            last_scan
        FROM vnx_code_quality
        WHERE datetime(last_scan) > datetime('now', ? || ' days')
          AND (critical_issues > 0 OR warning_issues > 0)
        ORDER BY datetime(last_scan) DESC
        LIMIT 10
        """

        cursor.execute(query, (f"-{days}",))
        results = cursor.fetchall()

        for row in results:
            file_path, complexity, critical_issues, warning_issues, suggested_track, last_scan = row
            recent_issues.append({
                "file": file_path,
                "complexity": round(complexity, 2) if complexity else 0,
                "critical_issues": int(critical_issues or 0),
                "warning_issues": int(warning_issues or 0),
                "suggested_track": suggested_track or "C",
                "last_scan": last_scan
            })

        conn.close()

    except Exception as e:
        logger.error(f"Error querying recent issues: {e}")

    return recent_issues

def build_risk_flags(hotspots: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Build risk flags based on hotspot analysis.
    """
    risk_flags = {
        "critical_count": 0,
        "high_risk_areas": [],
        "track_load": {"A": 0, "B": 0, "C": 0}
    }

    for hotspot in hotspots:
        # Count critical issues
        if hotspot.get("severity") == "critical" or hotspot.get("critical_issues", 0) > 0:
            risk_flags["critical_count"] += 1

        # Track high-risk areas
        if hotspot.get("complexity", 0) >= 75:
            risk_flags["high_risk_areas"].append({
                "file": os.path.basename(hotspot["file"]),
                "complexity": hotspot["complexity"],
                "track": hotspot.get("suggested_track") or "C"
            })

        # Track load distribution
        track = hotspot.get("suggested_track", "C")
        risk_flags["track_load"][track] += 1

    # Limit high-risk areas to top 5
    risk_flags["high_risk_areas"] = sorted(
        risk_flags["high_risk_areas"],
        key=lambda x: x["complexity"],
        reverse=True
    )[:5]

    return risk_flags

def generate_recommendations(hotspots: List[Dict[str, Any]], risk_flags: Dict[str, Any]) -> List[str]:
    """
    Generate actionable recommendations based on quality analysis.
    """
    recommendations = []

    # Critical complexity recommendations
    if risk_flags["critical_count"] > 0:
        recommendations.append(
            f"URGENT: {risk_flags['critical_count']} critical complexity hotspots need immediate refactoring"
        )

    # Track load balancing
    track_loads = risk_flags["track_load"]
    if track_loads["A"] > track_loads["B"] * 2:
        recommendations.append("Consider redistributing Track A work to Track B for better load balance")
    elif track_loads["B"] > track_loads["A"] * 2:
        recommendations.append("Consider redistributing Track B work to Track A for better load balance")

    # High-risk area recommendations
    if len(risk_flags["high_risk_areas"]) >= 3:
        recommendations.append(
            f"Focus refactoring on {len(risk_flags['high_risk_areas'])} high-complexity files"
        )

    # General recommendations
    if not recommendations:
        if hotspots:
            recommendations.append("Quality metrics stable - continue monitoring complexity trends")
        else:
            recommendations.append("No quality issues detected - system healthy")

    return recommendations

def build_quality_digest(
    limit_hotspots: int = 10,
    recent_days: int = 7
) -> Dict[str, Any]:
    """
    Build the complete quality digest for T0.
    """
    # Query quality metrics
    hotspots = query_quality_metrics(QUALITY_DB, limit_hotspots)
    recent_issues = query_recent_issues(QUALITY_DB, recent_days)

    # Build risk flags
    risk_flags = build_risk_flags(hotspots)

    # Generate recommendations
    recommendations = generate_recommendations(hotspots, risk_flags)

    # Build digest
    digest = {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "schema_version": "1.0",
        "total_hotspots": _count_total_hotspots(QUALITY_DB),
        "recent_issues_7d": len(recent_issues),
        "top_hotspots": hotspots[:10],  # Top 10 complexity hotspots
        "risk_flags": risk_flags,
        "track_routing": {
            "recommended": {
                track: [h["file"] for h in hotspots if h.get("suggested_track") == track][:3]
                for track in ["A", "B", "C"]
            }
        },
        "recommendations": recommendations,
        "metadata": {
            "database": str(QUALITY_DB),
            "query_limit": limit_hotspots,
            "recent_days": recent_days
        }
    }

    return digest

def _count_total_hotspots(db_path: Path) -> int:
    if not db_path.exists():
        return 0
    try:
        conn = sqlite3.connect(str(db_path))
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM files_needing_attention")
        count = int(cur.fetchone()[0] or 0)
        conn.close()
        return count
    except Exception:
        return 0

def save_digest(digest: Dict[str, Any], output_path: Path) -> None:
    """
    Save digest to JSON file with proper formatting.
    """
    try:
        # Ensure directory exists
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Write with pretty formatting
        with open(output_path, 'w') as f:
            json.dump(digest, f, indent=2, ensure_ascii=False)

        logger.info(f"✅ Quality digest saved to {output_path}")

    except Exception as e:
        logger.error(f"Failed to save digest: {e}")
        raise

def main():
    """
    Main entry point for quality digest generation.
    """
    logger.info("=== T0 Quality Digest Generator ===")

    # Check database exists
    if not QUALITY_DB.exists():
        logger.warning(f"Quality database not found at {QUALITY_DB}")
        # Create empty digest
        empty_digest = {
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "schema_version": "1.0",
            "error": "quality_intelligence.db not found",
            "total_hotspots": 0,
            "top_hotspots": [],
            "risk_flags": {
                "critical_count": 0,
                "high_risk_areas": [],
                "track_load": {"A": 0, "B": 0, "C": 0}
            },
            "recommendations": ["Quality database not initialized - run quality scanner first"]
        }
        save_digest(empty_digest, OUTPUT_FILE)
        return

    # Build digest
    digest = build_quality_digest()

    # Save to file
    save_digest(digest, OUTPUT_FILE)

    # Print summary
    print(f"\n📊 Quality Digest Summary:")
    print(f"  - Total hotspots: {digest['total_hotspots']}")
    print(f"  - Critical issues: {digest['risk_flags']['critical_count']}")
    print(f"  - Track distribution: A={digest['risk_flags']['track_load']['A']}, "
          f"B={digest['risk_flags']['track_load']['B']}, "
          f"C={digest['risk_flags']['track_load']['C']}")

    if digest['recommendations']:
        print(f"\n📌 Recommendations:")
        for rec in digest['recommendations']:
            print(f"  - {rec}")

if __name__ == "__main__":
    main()
