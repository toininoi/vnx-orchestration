#!/usr/bin/env python3
"""
T0 Orchestrator Ledger Interface

Simple interface for T0 to query VNX State Ledger for orchestration decisions.
Provides high-level functions for common orchestration queries.
"""

import sys
import json
from pathlib import Path

# Add ledger to path
sys.path.append(str(Path(__file__).parent))
from api.ledger_api import VNXLedgerAPI


class T0LedgerInterface:
    """High-level interface for T0 orchestration queries"""

    def __init__(self):
        self.api = VNXLedgerAPI()

    def get_system_status(self) -> dict:
        """Get current system status for T0 dashboard"""
        try:
            state = self.api.get_current_state()

            # Format for T0 dashboard
            status = {
                "timestamp": state["timestamp"],
                "terminals": {},
                "system_health": {
                    "success_rate": state["system_metrics"]["success_rate_24h"],
                    "total_events": state["system_metrics"]["total_events_24h"],
                    "status": "healthy" if state["system_metrics"]["success_rate_24h"] > 80 else "degraded"
                }
            }

            # Add terminal status
            for terminal, events in state["terminal_states"].items():
                if events:
                    latest = events[0]
                    status["terminals"][terminal] = {
                        "status": latest["status"],
                        "last_activity": latest["timestamp"],
                        "current_work": latest["summary"][:60] + "..." if len(latest["summary"]) > 60 else latest["summary"]
                    }
                else:
                    status["terminals"][terminal] = {
                        "status": "idle",
                        "last_activity": "unknown",
                        "current_work": "no recent activity"
                    }

            return status

        except Exception as e:
            return {"error": f"Failed to get system status: {e}"}

    def get_orchestration_recommendations(self) -> dict:
        """Get AI-powered recommendations for T0 orchestration"""
        try:
            recommendations = self.api.recommend_action()

            # Format for T0 consumption
            result = {
                "timestamp": recommendations["analysis_timestamp"],
                "summary": recommendations["context_summary"],
                "recommendations": []
            }

            for rec in recommendations["recommendations"]:
                result["recommendations"].append({
                    "priority": rec["priority"],
                    "action": rec["action"],
                    "terminal": rec.get("terminal", "N/A"),
                    "type": rec["type"],
                    "rationale": self._format_rationale(rec)
                })

            return result

        except Exception as e:
            return {"error": f"Failed to get recommendations: {e}"}

    def get_terminal_performance(self, hours: int = 24) -> dict:
        """Get performance analysis for each terminal"""
        try:
            patterns = self.api.get_success_patterns()

            result = {
                "analysis_period": f"{hours} hours",
                "terminals": {}
            }

            for perf in patterns["terminal_performance"]:
                terminal = perf["terminal"]
                result["terminals"][terminal] = {
                    "success_rate": perf["success_rate"],
                    "total_events": perf["total_events"],
                    "sessions": perf["sessions"],
                    "performance_grade": self._calculate_grade(perf["success_rate"])
                }

            return result

        except Exception as e:
            return {"error": f"Failed to get terminal performance: {e}"}

    def get_bottlenecks(self) -> dict:
        """Identify current system bottlenecks"""
        try:
            bottlenecks = self.api.get_bottlenecks()

            result = {
                "timestamp": bottlenecks["analysis_timestamp"],
                "blocked_tasks": len(bottlenecks["blocked_tasks"]),
                "slow_terminals": len(bottlenecks["slow_terminals"]),
                "issues": []
            }

            # Format blocked tasks
            for task in bottlenecks["blocked_tasks"]:
                result["issues"].append({
                    "type": "blocked_task",
                    "terminal": task["terminal"],
                    "gate": task["gate"],
                    "count": task["blocked_count"],
                    "severity": "high" if task["blocked_count"] > 3 else "medium"
                })

            # Format slow terminals
            for terminal in bottlenecks["slow_terminals"]:
                if terminal["avg_gap_minutes"] > 30:  # More than 30 min between actions
                    result["issues"].append({
                        "type": "slow_terminal",
                        "terminal": terminal["terminal"],
                        "avg_gap": f"{terminal['avg_gap_minutes']:.1f} minutes",
                        "severity": "medium"
                    })

            return result

        except Exception as e:
            return {"error": f"Failed to get bottlenecks: {e}"}

    def refresh_ledger(self) -> dict:
        """Refresh ledger data and return summary"""
        try:
            result = self.api.refresh()
            return {
                "success": True,
                "events_processed": result["events_processed"],
                "correlations_found": result["correlations_found"],
                "timestamp": result["refresh_timestamp"]
            }
        except Exception as e:
            return {"error": f"Failed to refresh ledger: {e}"}

    def _format_rationale(self, recommendation: dict) -> str:
        """Format recommendation rationale for T0"""
        rationale_parts = []

        if "context" in recommendation:
            context = recommendation["context"]
            if isinstance(context, dict):
                if "success_rate" in context:
                    rationale_parts.append(f"Success rate: {context['success_rate']}%")
                if "event_count" in context:
                    rationale_parts.append(f"Event count: {context['event_count']}")

        return " | ".join(rationale_parts) if rationale_parts else "Based on system analysis"

    def _calculate_grade(self, success_rate: float) -> str:
        """Calculate performance grade from success rate"""
        if success_rate >= 95:
            return "A+"
        elif success_rate >= 90:
            return "A"
        elif success_rate >= 85:
            return "B+"
        elif success_rate >= 80:
            return "B"
        elif success_rate >= 70:
            return "C"
        else:
            return "D"


def main():
    """CLI interface for T0"""
    if len(sys.argv) < 2:
        print("T0 Ledger Interface")
        print("\nUsage:")
        print("  python t0_ledger_interface.py status      - Get system status")
        print("  python t0_ledger_interface.py recommend   - Get orchestration recommendations")
        print("  python t0_ledger_interface.py performance - Get terminal performance analysis")
        print("  python t0_ledger_interface.py bottlenecks - Identify system bottlenecks")
        print("  python t0_ledger_interface.py refresh     - Refresh ledger data")
        return

    command = sys.argv[1].lower()
    interface = T0LedgerInterface()

    try:
        if command == "status":
            result = interface.get_system_status()
        elif command == "recommend":
            result = interface.get_orchestration_recommendations()
        elif command == "performance":
            result = interface.get_terminal_performance()
        elif command == "bottlenecks":
            result = interface.get_bottlenecks()
        elif command == "refresh":
            result = interface.refresh_ledger()
        else:
            result = {"error": f"Unknown command: {command}"}

        print(json.dumps(result, indent=2))

    except Exception as e:
        print(json.dumps({"error": f"Command failed: {e}"}, indent=2))
        sys.exit(1)


if __name__ == "__main__":
    main()