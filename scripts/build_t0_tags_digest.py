#!/usr/bin/env python3
"""
T0 Tags Digest Builder - Phase 1
=================================
Purpose: Make report tags actionable for T0 without ad-hoc queries

Input: unified_reports/index.ndjson
Output: VNX_STATE_DIR/t0_tags_digest.json

Handles schema normalization:
- file vs report_path
- tags as array vs tags as object
- missing fields

Author: T-MANAGER
Date: 2026-01-11
Version: 1.0
"""

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Set
from collections import defaultdict
from pathlib import Path

# Configuration
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))
try:
    from vnx_paths import ensure_env
except Exception as exc:
    raise SystemExit(f"Failed to load vnx_paths: {exc}")

PATHS = ensure_env()
REPORTS_INDEX = os.path.join(PATHS["VNX_REPORTS_DIR"], 'index.ndjson')
OUTPUT_PATH = os.path.join(PATHS["VNX_STATE_DIR"], 't0_tags_digest.json')

# Time windows
WINDOW_7D = timedelta(days=7)
WINDOW_30D = timedelta(days=30)


def normalize_report_entry(entry: Dict) -> Dict:
    """
    Normalize schema variations in index.ndjson entries

    Handles:
    - file vs report_path
    - tags as array vs object
    - missing timestamp
    """
    normalized = {}

    # Normalize file path
    if 'file' in entry:
        normalized['file'] = entry['file']
    elif 'report_path' in entry:
        normalized['file'] = entry['report_path']
    elif 'path' in entry:
        normalized['file'] = entry['path']
    else:
        normalized['file'] = 'unknown'

    # Normalize timestamp
    if 'timestamp' in entry:
        normalized['timestamp'] = entry['timestamp']
    else:
        # Try to extract from filename: YYYYMMDD-HHMMSS
        filename = normalized['file']
        try:
            # Format: 20250928-221200-...
            date_part = filename.split('-')[0]
            time_part = filename.split('-')[1]
            normalized['timestamp'] = f"{date_part[:4]}-{date_part[4:6]}-{date_part[6:8]}T{time_part[:2]}:{time_part[2:4]}:{time_part[4:6]}Z"
        except:
            # Fallback to epoch start
            normalized['timestamp'] = '1970-01-01T00:00:00Z'

    # Normalize tags
    tags = []
    if 'tags' in entry:
        if isinstance(entry['tags'], list):
            tags = entry['tags']
        elif isinstance(entry['tags'], dict):
            # Flatten tag object to list
            for key, values in entry['tags'].items():
                if isinstance(values, list):
                    tags.extend(values)
                else:
                    tags.append(values)
        elif isinstance(entry['tags'], str):
            tags = [entry['tags']]
    normalized['tags'] = tags

    # Copy other useful fields
    for field in ['summary', 'status', 'terminal', 'type', 'topic', 'confidence']:
        if field in entry:
            normalized[field] = entry[field]

    return normalized


def parse_timestamp(timestamp_str: str) -> datetime:
    """Parse timestamp with fallback handling"""
    try:
        # Try ISO format first
        dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except:
        # Fallback to epoch
        return datetime(1970, 1, 1, tzinfo=timezone.utc)


def build_tags_digest() -> Dict:
    """
    Build T0 tags digest from report index

    Returns:
    {
        "updated_at": "2026-01-11T20:00:00Z",
        "total_reports": 73,
        "top_tags_7d": [
            {
                "tag": "storage-failure",
                "count": 12,
                "examples": [
                    {
                        "file": "...",
                        "timestamp": "...",
                        "summary": "..."
                    }
                ]
            }
        ],
        "top_tags_30d": [...],
        "all_tags": ["tag1", "tag2", ...]
    }
    """

    if not os.path.exists(REPORTS_INDEX):
        print(f"Warning: Report index not found at {REPORTS_INDEX}")
        return {
            'updated_at': datetime.now(timezone.utc).isoformat(),
            'total_reports': 0,
            'top_tags_7d': [],
            'top_tags_30d': [],
            'all_tags': [],
            'error': 'Report index not found'
        }

    # Parse all reports
    reports = []
    skipped = 0

    with open(REPORTS_INDEX, 'r') as f:
        for line_num, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue

            try:
                entry = json.loads(line)
                normalized = normalize_report_entry(entry)
                reports.append(normalized)
            except json.JSONDecodeError as e:
                print(f"Warning: Invalid JSON at line {line_num}: {e}")
                skipped += 1
                continue
            except Exception as e:
                print(f"Warning: Error processing line {line_num}: {e}")
                skipped += 1
                continue

    print(f"Parsed {len(reports)} reports ({skipped} skipped)")

    # Calculate time windows
    now = datetime.now(timezone.utc)
    cutoff_7d = now - WINDOW_7D
    cutoff_30d = now - WINDOW_30D

    # Aggregate tags by time window
    tags_7d = defaultdict(lambda: {'count': 0, 'reports': []})
    tags_30d = defaultdict(lambda: {'count': 0, 'reports': []})
    all_tags_set: Set[str] = set()

    for report in reports:
        timestamp = parse_timestamp(report['timestamp'])
        tags = report.get('tags', [])

        # Deduplicate and clean tags
        cleaned_tags = []
        for tag in tags:
            # Remove hash prefix if present
            clean_tag = tag.lstrip('#').strip().lower()
            if clean_tag and clean_tag not in cleaned_tags:
                cleaned_tags.append(clean_tag)

        for tag in cleaned_tags:
            all_tags_set.add(tag)

            # Add to appropriate time windows
            if timestamp >= cutoff_7d:
                tags_7d[tag]['count'] += 1
                if len(tags_7d[tag]['reports']) < 3:  # Keep only top 3 examples
                    tags_7d[tag]['reports'].append({
                        'file': report['file'],
                        'timestamp': report['timestamp'],
                        'summary': report.get('summary', 'No summary available')[:200]
                    })

            if timestamp >= cutoff_30d:
                tags_30d[tag]['count'] += 1
                if len(tags_30d[tag]['reports']) < 3:
                    tags_30d[tag]['reports'].append({
                        'file': report['file'],
                        'timestamp': report['timestamp'],
                        'summary': report.get('summary', 'No summary available')[:200]
                    })

    # Sort and format top tags
    def format_top_tags(tag_dict: Dict, top_n: int = 20) -> List[Dict]:
        sorted_tags = sorted(tag_dict.items(), key=lambda x: x[1]['count'], reverse=True)
        return [
            {
                'tag': tag,
                'count': data['count'],
                'examples': data['reports']
            }
            for tag, data in sorted_tags[:top_n]
        ]

    top_tags_7d = format_top_tags(tags_7d)
    top_tags_30d = format_top_tags(tags_30d)

    # Build digest
    digest = {
        'updated_at': now.isoformat(),
        'total_reports': len(reports),
        'total_reports_7d': sum(1 for r in reports if parse_timestamp(r['timestamp']) >= cutoff_7d),
        'total_reports_30d': sum(1 for r in reports if parse_timestamp(r['timestamp']) >= cutoff_30d),
        'top_tags_7d': top_tags_7d,
        'top_tags_30d': top_tags_30d,
        'all_tags': sorted(list(all_tags_set)),
        'schema_version': '1.0'
    }

    return digest


def write_digest(digest: Dict) -> None:
    """Write digest to file atomically"""
    temp_path = f"{OUTPUT_PATH}.tmp"

    try:
        with open(temp_path, 'w') as f:
            json.dump(digest, f, indent=2)

        os.rename(temp_path, OUTPUT_PATH)
        print(f"Digest written to {OUTPUT_PATH}")
    except Exception as e:
        print(f"Error writing digest: {e}")
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise


def main():
    """Main entry point"""
    print("=" * 80)
    print("T0 Tags Digest Builder - Phase 1")
    print("=" * 80)
    print(f"Input: {REPORTS_INDEX}")
    print(f"Output: {OUTPUT_PATH}")
    print("")

    # Build digest
    digest = build_tags_digest()

    # Write digest
    write_digest(digest)

    # Print summary
    print("")
    print("Digest Summary:")
    print(f"  - Total reports: {digest['total_reports']}")
    print(f"  - Reports (7d): {digest['total_reports_7d']}")
    print(f"  - Reports (30d): {digest['total_reports_30d']}")
    print(f"  - Unique tags: {len(digest['all_tags'])}")
    print(f"  - Top tags (7d): {len(digest['top_tags_7d'])}")
    print(f"  - Top tags (30d): {len(digest['top_tags_30d'])}")

    if digest['top_tags_7d']:
        print("")
        print("Top 5 Tags (Last 7 Days):")
        for i, tag_data in enumerate(digest['top_tags_7d'][:5], 1):
            print(f"  {i}. {tag_data['tag']} ({tag_data['count']} reports)")


if __name__ == '__main__':
    main()
