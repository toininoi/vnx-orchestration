#!/usr/bin/env python3
"""
VNX State Ledger CLI

Command-line interface for T0 orchestrator to query VNX system state.
"""

import sys
import json
from pathlib import Path

# Add ledger to path
sys.path.append(str(Path(__file__).parent))
from api.ledger_api import VNXLedgerAPI


def format_terminal_status(state):
    """Format terminal status for T0"""
    print("🟢 VNX SYSTEM STATE")
    print("=" * 50)

    for terminal in ['T1', 'T2', 'T3']:
        events = state["terminal_states"].get(terminal, [])
        if events:
            latest = events[0]
            status_icon = {
                'success': '✅',
                'blocked': '🚫',
                'fail': '❌',
                'in_progress': '🔄',
                'working': '🔄'
            }.get(latest['status'], '❓')

            print(f"{status_icon} {terminal}: {latest['status']} ({latest['event_type']})")
            if latest.get('summary'):
                print(f"   └─ {latest['summary'][:80]}...")
        else:
            print(f"❓ {terminal}: No recent activity")

    metrics = state.get("system_metrics", {})
    print(f"\n📊 Success Rate (24h): {metrics.get('success_rate_24h', 0)}%")
    print(f"📈 Total Events: {metrics.get('total_events_24h', 0)}")


def show_recent_timeline(api, hours=2):
    """Show recent activity timeline"""
    print(f"\n📅 RECENT ACTIVITY ({hours}h)")
    print("=" * 50)

    timeline = api.get_timeline(limit=10)

    for event in timeline[:10]:
        timestamp = event['timestamp'][:16]  # YYYY-MM-DD HH:MM
        terminal = event['terminal']
        status_icon = {
            'success': '✅',
            'blocked': '🚫',
            'fail': '❌',
            'in_progress': '🔄'
        }.get(event['status'], '❓')

        print(f"{timestamp} {status_icon} {terminal}: {event['summary'][:60]}...")


def show_recommendations(api):
    """Show T0 orchestration recommendations"""
    print(f"\n🎯 T0 RECOMMENDATIONS")
    print("=" * 50)

    try:
        recs = api.recommend_action()

        if not recs.get("recommendations"):
            print("✅ All systems operating normally")
            return

        for rec in recs["recommendations"][:5]:
            priority_icon = {
                'high': '🔴',
                'medium': '🟡',
                'low': '🟢'
            }.get(rec['priority'], '❓')

            print(f"{priority_icon} {rec['priority'].upper()}: {rec['action']}")
            print(f"   Terminal: {rec.get('terminal', 'N/A')}")
            print(f"   Type: {rec['type']}")
            print()

    except Exception as e:
        print(f"⚠️  Error generating recommendations: {e}")


def show_correlations(api, correlation_id):
    """Show all events for a correlation ID"""
    print(f"\n🔗 CORRELATION: {correlation_id}")
    print("=" * 50)

    events = api.get_correlation(correlation_id)

    if not events:
        print("No events found for this correlation ID")
        return

    for event in events:
        timestamp = event['timestamp'][:16]
        status_icon = {
            'success': '✅',
            'blocked': '🚫',
            'fail': '❌',
            'in_progress': '🔄'
        }.get(event['status'], '❓')

        print(f"{timestamp} {status_icon} {event['terminal']} [{event['source']}] {event['summary']}")


def main():
    """Main CLI interface"""
    if len(sys.argv) < 2:
        print("VNX State Ledger CLI")
        print("\nUsage:")
        print("  python vnx_ledger_cli.py status       - Show current system state")
        print("  python vnx_ledger_cli.py timeline     - Show recent activity")
        print("  python vnx_ledger_cli.py recommend    - Show T0 recommendations")
        print("  python vnx_ledger_cli.py refresh      - Refresh ledger data")
        print("  python vnx_ledger_cli.py search <query> - Search events")
        print("  python vnx_ledger_cli.py corr <id>    - Show correlation events")
        return

    command = sys.argv[1].lower()

    try:
        api = VNXLedgerAPI()

        if command == "status":
            state = api.get_current_state()
            format_terminal_status(state)

        elif command == "timeline":
            state = api.get_current_state()
            format_terminal_status(state)
            show_recent_timeline(api)

        elif command == "recommend":
            state = api.get_current_state()
            format_terminal_status(state)
            show_recommendations(api)

        elif command == "refresh":
            print("🔄 Refreshing VNX State Ledger...")
            result = api.refresh()
            print(f"✅ Processed {result['events_processed']} events")
            print(f"🔗 Found {result['correlations_found']} correlations")

        elif command == "search":
            if len(sys.argv) < 3:
                print("Usage: python vnx_ledger_cli.py search <query>")
                return

            query = sys.argv[2]
            events = api.search_events(query, limit=10)

            print(f"\n🔍 SEARCH: '{query}'")
            print("=" * 50)

            for event in events:
                timestamp = event['timestamp'][:16]
                print(f"{timestamp} {event['terminal']}: {event['summary']}")

        elif command == "corr":
            if len(sys.argv) < 3:
                print("Usage: python vnx_ledger_cli.py corr <correlation_id>")
                return

            correlation_id = sys.argv[2]
            show_correlations(api, correlation_id)

        elif command == "stats":
            stats = api.get_statistics()

            print("\n📊 VNX STATISTICS")
            print("=" * 50)

            print("Event Types:")
            for event_type, count in stats["event_types"].items():
                print(f"  {event_type}: {count}")

            print("\nStatus Distribution:")
            for status, count in stats["status_distribution"].items():
                print(f"  {status}: {count}")

        else:
            print(f"Unknown command: {command}")

    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()