#!/usr/bin/env python3
"""
VNX State Ledger - Correlation Engine

Correlates receipts and reports across VNX terminals to reconstruct system state
and provide intelligence for T0 orchestration decisions.
"""

import json
import sqlite3
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass


@dataclass
class VNXEvent:
    """Normalized VNX system event"""
    event_id: str
    timestamp: datetime
    source: str  # receipt|report|status
    terminal: str  # T1|T2|T3
    event_type: str  # task_ack|task_complete|report_generated|status_change
    gate: Optional[str]  # implementation|testing|review|validation
    status: str  # success|blocked|fail|in_progress
    correlation_id: Optional[str]
    report_path: Optional[str]
    summary: str
    metadata: Dict


class VNXCorrelationEngine:
    """Core engine for correlating VNX system events"""

    def __init__(self, vnx_root: str = None):
        if vnx_root is None:
            # Default: resolve relative to this file's location (ledger/engine/ -> vnx-system root)
            vnx_root = str(Path(__file__).resolve().parent.parent.parent)
        self.vnx_root = Path(vnx_root)
        self.state_dir = self.vnx_root / "state"
        self.reports_dir = self.vnx_root / "unified_reports"
        self.ledger_dir = self.vnx_root / "ledger"
        self.db_path = self.ledger_dir / "storage" / "events.db"

        # Initialize database
        self._init_database()

    def _init_database(self) -> None:
        """Initialize SQLite database for event storage"""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)

        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS events (
                    event_id TEXT PRIMARY KEY,
                    timestamp TEXT NOT NULL,
                    source TEXT NOT NULL,
                    terminal TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    gate TEXT,
                    status TEXT NOT NULL,
                    correlation_id TEXT,
                    report_path TEXT,
                    summary TEXT NOT NULL,
                    metadata TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)

            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_timestamp ON events(timestamp)
            """)

            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_terminal ON events(terminal)
            """)

            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_correlation ON events(correlation_id)
            """)

    def parse_receipts(self) -> List[VNXEvent]:
        """Parse all receipt files and extract events"""
        events = []

        # Parse t0_receipts.ndjson (main receipt file)
        t0_receipts = self.state_dir / "t0_receipts.ndjson"
        if t0_receipts.exists():
            events.extend(self._parse_receipt_file(t0_receipts))

        # Parse unified_receipts.ndjson
        unified_receipts = self.state_dir / "unified_receipts.ndjson"
        if unified_receipts.exists():
            events.extend(self._parse_receipt_file(unified_receipts))

        # Parse legacy track receipts
        for track in ['A', 'B', 'C']:
            track_file = self.state_dir / f"receipts_track_{track}.ndjson"
            if track_file.exists():
                events.extend(self._parse_receipt_file(track_file))

        return events

    def _parse_receipt_file(self, file_path: Path) -> List[VNXEvent]:
        """Parse individual receipt file"""
        events = []

        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue

                    try:
                        receipt = json.loads(line)
                        event = self._receipt_to_event(receipt, f"{file_path.name}:{line_num}")
                        if event:
                            events.append(event)
                    except json.JSONDecodeError as e:
                        print(f"Warning: Invalid JSON in {file_path}:{line_num}: {e}")
                        continue
        except FileNotFoundError:
            pass

        return events

    def _receipt_to_event(self, receipt: Dict, source_ref: str) -> Optional[VNXEvent]:
        """Convert receipt JSON to VNXEvent"""
        try:
            # Extract timestamp
            timestamp_str = receipt.get('timestamp', receipt.get('ts', ''))
            if not timestamp_str:
                timestamp = datetime.now()
            else:
                try:
                    timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                except ValueError:
                    timestamp = datetime.now()

            # Map track to terminal
            track = receipt.get('track', '')
            terminal_map = {'A': 'T1', 'B': 'T2', 'C': 'T3'}
            terminal = terminal_map.get(track, track if track.startswith('T') else 'T0')

            # Determine event type
            event_type = receipt.get('event', 'unknown')
            if event_type not in ['task_ack', 'task_complete', 'task_receipt']:
                event_type = 'task_receipt'  # Default for legacy

            # Generate correlation ID from report path or task ID
            correlation_id = None
            report_path = receipt.get('report_path')
            if report_path:
                # Extract correlation ID from report filename
                match = re.search(r'(\d{8}-\d{6})', str(report_path))
                if match:
                    correlation_id = match.group(1)

            if not correlation_id:
                correlation_id = receipt.get('task_id', receipt.get('run_id'))

            return VNXEvent(
                event_id=f"{source_ref}_{timestamp.isoformat()}",
                timestamp=timestamp,
                source="receipt",
                terminal=terminal,
                event_type=event_type,
                gate=receipt.get('gate'),
                status=receipt.get('status', 'unknown'),
                correlation_id=correlation_id,
                report_path=report_path,
                summary=receipt.get('summary', '')[:500],  # Limit length
                metadata=receipt
            )

        except Exception as e:
            print(f"Warning: Failed to parse receipt {source_ref}: {e}")
            return None

    def parse_reports(self) -> List[VNXEvent]:
        """Parse all report files and extract events"""
        events = []

        if not self.reports_dir.exists():
            return events

        for report_file in self.reports_dir.glob("*.md"):
            if report_file.name.startswith('latest-'):
                continue  # Skip status files

            event = self._report_to_event(report_file)
            if event:
                events.append(event)

        return events

    def _report_to_event(self, report_path: Path) -> Optional[VNXEvent]:
        """Convert report file to VNXEvent"""
        try:
            # Parse filename: YYYYMMDD-HHMMSS-TN-TYPE-topic.md
            filename = report_path.stem
            parts = filename.split('-')

            if len(parts) < 4:
                return None

            date_part = parts[0]
            time_part = parts[1]
            terminal = parts[2]
            event_type = parts[3]
            topic = '-'.join(parts[4:]) if len(parts) > 4 else 'unknown'

            # Parse timestamp
            timestamp_str = f"{date_part}-{time_part}"
            try:
                timestamp = datetime.strptime(timestamp_str, "%Y%m%d-%H%M%S")
            except ValueError:
                timestamp = datetime.fromtimestamp(report_path.stat().st_mtime)

            # Read report header for metadata
            metadata = {"filename": filename, "topic": topic}
            summary = f"{event_type}: {topic.replace('-', ' ')}"
            gate = None
            status = "completed"

            try:
                with open(report_path, 'r') as f:
                    content = f.read(2000)  # Read first 2KB for header

                    # Extract gate and status from header
                    if "**Gate**:" in content:
                        gate_match = re.search(r'\*\*Gate\*\*:\s*(\w+)', content)
                        if gate_match:
                            gate = gate_match.group(1)

                    if "**Status**:" in content:
                        status_match = re.search(r'\*\*Status\*\*:\s*(\w+)', content)
                        if status_match:
                            status = status_match.group(1)

                    # Extract first line of summary section
                    summary_match = re.search(r'## Summary\s*\n([^\n]+)', content)
                    if summary_match:
                        summary = summary_match.group(1).strip()[:200]

            except Exception:
                pass  # Use defaults if header parsing fails

            return VNXEvent(
                event_id=f"report_{filename}",
                timestamp=timestamp,
                source="report",
                terminal=terminal,
                event_type="report_generated",
                gate=gate,
                status=status,
                correlation_id=f"{date_part}-{time_part}",
                report_path=str(report_path.relative_to(self.vnx_root)),
                summary=summary,
                metadata=metadata
            )

        except Exception as e:
            print(f"Warning: Failed to parse report {report_path}: {e}")
            return None

    def correlate_events(self, events: List[VNXEvent]) -> Dict[str, List[VNXEvent]]:
        """Group events by correlation ID"""
        correlations = {}

        for event in events:
            if event.correlation_id:
                if event.correlation_id not in correlations:
                    correlations[event.correlation_id] = []
                correlations[event.correlation_id].append(event)

        return correlations

    def store_events(self, events: List[VNXEvent]) -> None:
        """Store events in SQLite database"""
        with sqlite3.connect(self.db_path) as conn:
            for event in events:
                conn.execute("""
                    INSERT OR REPLACE INTO events
                    (event_id, timestamp, source, terminal, event_type, gate, status,
                     correlation_id, report_path, summary, metadata)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    event.event_id,
                    event.timestamp.isoformat(),
                    event.source,
                    event.terminal,
                    event.event_type,
                    event.gate,
                    event.status,
                    event.correlation_id,
                    event.report_path,
                    event.summary,
                    json.dumps(event.metadata)
                ))

    def get_current_state(self) -> Dict:
        """Get current system state"""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row

            # Get latest events for each terminal
            terminal_states = {}
            for terminal in ['T1', 'T2', 'T3']:
                cursor = conn.execute("""
                    SELECT * FROM events
                    WHERE terminal = ?
                    ORDER BY timestamp DESC
                    LIMIT 5
                """, (terminal,))

                events = [dict(row) for row in cursor.fetchall()]
                terminal_states[terminal] = events

            return {
                "timestamp": datetime.now().isoformat(),
                "terminal_states": terminal_states,
                "system_metrics": self._calculate_metrics(conn)
            }

    def _calculate_metrics(self, conn: sqlite3.Connection) -> Dict:
        """Calculate system metrics"""
        cursor = conn.execute("""
            SELECT
                COUNT(*) as total_events,
                COUNT(DISTINCT correlation_id) as total_sessions,
                AVG(CASE WHEN status = 'success' THEN 1.0 ELSE 0.0 END) as success_rate
            FROM events
            WHERE timestamp > datetime('now', '-24 hours')
        """)

        row = cursor.fetchone()
        return {
            "total_events_24h": row[0],
            "total_sessions_24h": row[1],
            "success_rate_24h": round(row[2] * 100, 1) if row[2] else 0
        }

    def refresh_ledger(self) -> Dict:
        """Refresh ledger with latest data"""
        print("🔄 Refreshing VNX State Ledger...")

        # Parse all events
        receipt_events = self.parse_receipts()
        report_events = self.parse_reports()
        all_events = receipt_events + report_events

        print(f"📊 Parsed {len(receipt_events)} receipt events, {len(report_events)} report events")

        # Store events
        self.store_events(all_events)

        # Correlate events
        correlations = self.correlate_events(all_events)

        print(f"🔗 Found {len(correlations)} correlation groups")

        # Get current state
        current_state = self.get_current_state()

        return {
            "refresh_timestamp": datetime.now().isoformat(),
            "events_processed": len(all_events),
            "correlations_found": len(correlations),
            "current_state": current_state
        }


def main():
    """Test the correlation engine"""
    engine = VNXCorrelationEngine()
    result = engine.refresh_ledger()

    print("\n✅ VNX State Ledger Refresh Complete")
    print(f"Events processed: {result['events_processed']}")
    print(f"Correlations found: {result['correlations_found']}")
    print(f"Success rate (24h): {result['current_state']['system_metrics']['success_rate_24h']}%")


if __name__ == "__main__":
    main()