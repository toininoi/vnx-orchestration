#!/usr/bin/env python3
"""
VNX State Ledger API

Provides query interface for T0 orchestration and system analysis.
"""

import json
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Union
from dataclasses import asdict

import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent.parent))

from engine.correlation_engine import VNXCorrelationEngine, VNXEvent


class VNXLedgerAPI:
    """Public API for VNX State Ledger queries"""

    def __init__(self, vnx_root: str = None):
        if vnx_root is None:
            # Default: resolve relative to this file's location (ledger/api/ -> vnx-system root)
            vnx_root = str(Path(__file__).resolve().parent.parent.parent)
        self.engine = VNXCorrelationEngine(vnx_root)
        self.db_path = self.engine.db_path

    def get_current_state(self) -> Dict:
        """Get real-time terminal status for T0 orchestration"""
        return self.engine.get_current_state()

    def get_timeline(self, start_time: Optional[str] = None, end_time: Optional[str] = None,
                    limit: int = 100) -> List[Dict]:
        """Get chronological event timeline"""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row

            query = "SELECT * FROM events"
            params = []

            if start_time or end_time:
                query += " WHERE"
                if start_time:
                    query += " timestamp >= ?"
                    params.append(start_time)
                if end_time:
                    if start_time:
                        query += " AND"
                    query += " timestamp <= ?"
                    params.append(end_time)

            query += " ORDER BY timestamp DESC LIMIT ?"
            params.append(limit)

            cursor = conn.execute(query, params)
            return [dict(row) for row in cursor.fetchall()]

    def get_terminal_history(self, terminal: str, hours: int = 24) -> List[Dict]:
        """Get activity history for specific terminal"""
        since = datetime.now() - timedelta(hours=hours)

        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row

            cursor = conn.execute("""
                SELECT * FROM events
                WHERE terminal = ? AND timestamp > ?
                ORDER BY timestamp DESC
            """, (terminal, since.isoformat()))

            return [dict(row) for row in cursor.fetchall()]

    def get_correlation(self, correlation_id: str) -> List[Dict]:
        """Get all events related to a correlation ID"""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row

            cursor = conn.execute("""
                SELECT * FROM events
                WHERE correlation_id = ?
                ORDER BY timestamp ASC
            """, (correlation_id,))

            return [dict(row) for row in cursor.fetchall()]

    def get_active_sessions(self) -> List[Dict]:
        """Get currently active work sessions"""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row

            # Find correlation IDs with recent activity but no completion
            cursor = conn.execute("""
                SELECT
                    correlation_id,
                    terminal,
                    MAX(timestamp) as last_activity,
                    COUNT(*) as event_count,
                    GROUP_CONCAT(DISTINCT status) as statuses
                FROM events
                WHERE timestamp > datetime('now', '-2 hours')
                  AND correlation_id IS NOT NULL
                GROUP BY correlation_id, terminal
                HAVING NOT statuses LIKE '%success%'
                   AND NOT statuses LIKE '%fail%'
                ORDER BY last_activity DESC
            """)

            return [dict(row) for row in cursor.fetchall()]

    def get_bottlenecks(self) -> Dict:
        """Identify system bottlenecks and blocked work"""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row

            # Find blocked tasks
            cursor = conn.execute("""
                SELECT
                    terminal,
                    gate,
                    COUNT(*) as blocked_count,
                    MAX(timestamp) as latest_block
                FROM events
                WHERE status IN ('blocked', 'fail')
                  AND timestamp > datetime('now', '-24 hours')
                GROUP BY terminal, gate
                ORDER BY blocked_count DESC
            """)

            blocked_tasks = [dict(row) for row in cursor.fetchall()]

            # Find slow terminals
            cursor = conn.execute("""
                SELECT
                    terminal,
                    AVG(julianday(timestamp) - julianday(LAG(timestamp) OVER (PARTITION BY terminal ORDER BY timestamp))) * 24 * 60 as avg_gap_minutes,
                    COUNT(*) as event_count
                FROM events
                WHERE timestamp > datetime('now', '-24 hours')
                GROUP BY terminal
                HAVING event_count > 5
                ORDER BY avg_gap_minutes DESC
            """)

            slow_terminals = [dict(row) for row in cursor.fetchall()]

            return {
                "blocked_tasks": blocked_tasks,
                "slow_terminals": slow_terminals,
                "analysis_timestamp": datetime.now().isoformat()
            }

    def get_success_patterns(self) -> Dict:
        """Analyze successful workflow patterns"""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row

            # Most successful gates by terminal
            cursor = conn.execute("""
                SELECT
                    terminal,
                    gate,
                    COUNT(*) as success_count,
                    ROUND(AVG(CASE WHEN status = 'success' THEN 1.0 ELSE 0.0 END) * 100, 1) as success_rate
                FROM events
                WHERE timestamp > datetime('now', '-7 days')
                  AND gate IS NOT NULL
                GROUP BY terminal, gate
                HAVING COUNT(*) >= 3
                ORDER BY success_rate DESC, success_count DESC
            """)

            successful_patterns = [dict(row) for row in cursor.fetchall()]

            # Terminal performance summary
            cursor = conn.execute("""
                SELECT
                    terminal,
                    COUNT(*) as total_events,
                    COUNT(DISTINCT correlation_id) as sessions,
                    ROUND(AVG(CASE WHEN status = 'success' THEN 1.0 ELSE 0.0 END) * 100, 1) as success_rate
                FROM events
                WHERE timestamp > datetime('now', '-7 days')
                  AND terminal IN ('T1', 'T2', 'T3')
                GROUP BY terminal
                ORDER BY success_rate DESC
            """)

            terminal_performance = [dict(row) for row in cursor.fetchall()]

            return {
                "successful_patterns": successful_patterns,
                "terminal_performance": terminal_performance,
                "analysis_period": "7 days"
            }

    def recommend_action(self, context: Optional[Dict] = None) -> Dict:
        """Provide T0 orchestration recommendations"""
        current_state = self.get_current_state()
        bottlenecks = self.get_bottlenecks()
        patterns = self.get_success_patterns()
        active_sessions = self.get_active_sessions()

        recommendations = []

        # Check for blocked terminals
        for terminal, events in current_state["terminal_states"].items():
            if events and events[0]["status"] == "blocked":
                recommendations.append({
                    "priority": "high",
                    "type": "unblock",
                    "terminal": terminal,
                    "action": f"Investigate {terminal} blockage",
                    "context": events[0]
                })

        # Check for idle high-performing terminals
        for perf in patterns["terminal_performance"]:
            terminal = perf["terminal"]
            if perf["success_rate"] > 80:
                terminal_events = current_state["terminal_states"].get(terminal, [])
                if not terminal_events or terminal_events[0]["status"] not in ["in_progress", "working"]:
                    recommendations.append({
                        "priority": "medium",
                        "type": "assign_work",
                        "terminal": terminal,
                        "action": f"Consider assigning work to high-performing {terminal}",
                        "context": {"success_rate": perf["success_rate"]}
                    })

        # Check for stale sessions
        for session in active_sessions:
            if session["event_count"] > 5:  # Multiple events but no completion
                recommendations.append({
                    "priority": "medium",
                    "type": "check_progress",
                    "terminal": session["terminal"],
                    "action": f"Check progress on correlation {session['correlation_id']}",
                    "context": session
                })

        return {
            "recommendations": recommendations,
            "analysis_timestamp": datetime.now().isoformat(),
            "context_summary": {
                "active_sessions": len(active_sessions),
                "blocked_tasks": len(bottlenecks["blocked_tasks"]),
                "avg_success_rate": current_state["system_metrics"]["success_rate_24h"]
            }
        }

    def search_events(self, query: str, limit: int = 50) -> List[Dict]:
        """Search events by summary content"""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row

            cursor = conn.execute("""
                SELECT * FROM events
                WHERE summary LIKE ? OR event_type LIKE ? OR gate LIKE ?
                ORDER BY timestamp DESC
                LIMIT ?
            """, (f"%{query}%", f"%{query}%", f"%{query}%", limit))

            return [dict(row) for row in cursor.fetchall()]

    def get_statistics(self) -> Dict:
        """Get comprehensive system statistics"""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row

            # Event counts by type
            cursor = conn.execute("""
                SELECT event_type, COUNT(*) as count
                FROM events
                WHERE timestamp > datetime('now', '-7 days')
                GROUP BY event_type
                ORDER BY count DESC
            """)
            event_types = dict(cursor.fetchall())

            # Status distribution
            cursor = conn.execute("""
                SELECT status, COUNT(*) as count
                FROM events
                WHERE timestamp > datetime('now', '-7 days')
                GROUP BY status
                ORDER BY count DESC
            """)
            status_dist = dict(cursor.fetchall())

            # Daily activity
            cursor = conn.execute("""
                SELECT
                    DATE(timestamp) as date,
                    COUNT(*) as events,
                    COUNT(DISTINCT correlation_id) as sessions
                FROM events
                WHERE timestamp > datetime('now', '-7 days')
                GROUP BY DATE(timestamp)
                ORDER BY date DESC
            """)
            daily_activity = [dict(row) for row in cursor.fetchall()]

            return {
                "event_types": event_types,
                "status_distribution": status_dist,
                "daily_activity": daily_activity,
                "statistics_period": "7 days",
                "generated_at": datetime.now().isoformat()
            }

    def refresh(self) -> Dict:
        """Refresh ledger data and return summary"""
        return self.engine.refresh_ledger()


def main():
    """Test the API"""
    api = VNXLedgerAPI()

    print("🔄 Refreshing ledger...")
    refresh_result = api.refresh()
    print(f"✅ Processed {refresh_result['events_processed']} events")

    print("\n📊 Current State:")
    state = api.get_current_state()
    for terminal, events in state["terminal_states"].items():
        if events:
            latest = events[0]
            print(f"  {terminal}: {latest['status']} ({latest['event_type']})")

    print(f"\n📈 System Metrics (24h):")
    metrics = state["system_metrics"]
    print(f"  Success Rate: {metrics['success_rate_24h']}%")
    print(f"  Total Events: {metrics['total_events_24h']}")

    print("\n🎯 Recommendations:")
    recommendations = api.recommend_action()
    for rec in recommendations["recommendations"][:3]:
        print(f"  {rec['priority'].upper()}: {rec['action']}")


if __name__ == "__main__":
    main()