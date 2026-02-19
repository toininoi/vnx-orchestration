#!/usr/bin/env python3
"""
Extract Open Items from Unified Reports
Scans unified_reports/ for ## Open Items sections and adds them to the tracker
"""

import re
import json
import argparse
from pathlib import Path
from datetime import datetime
import subprocess
import sys

# Path configuration
VNX_ROOT = Path(__file__).parent.parent

# Ensure lib/ is on sys.path for vnx_paths import
_lib_dir = str(Path(__file__).resolve().parent / "lib")
if _lib_dir not in sys.path:
    sys.path.insert(0, _lib_dir)

from vnx_paths import resolve_paths as _resolve_vnx_paths

_paths = _resolve_vnx_paths()
REPORTS_DIR = Path(_paths["VNX_REPORTS_DIR"])
PROCESSED_FILE = Path(_paths["VNX_STATE_DIR"]) / "open_items_processed.json"
OPEN_ITEMS_MANAGER = VNX_ROOT / "scripts" / "open_items_manager.py"

def load_processed():
    """Load list of already processed reports"""
    if not PROCESSED_FILE.exists():
        return {}

    with open(PROCESSED_FILE, 'r') as f:
        return json.load(f)

def save_processed(processed):
    """Save list of processed reports"""
    PROCESSED_FILE.parent.mkdir(exist_ok=True)
    with open(PROCESSED_FILE, 'w') as f:
        json.dump(processed, f, indent=2)

def extract_items_from_report(report_path):
    """Extract open items from a unified report markdown file"""
    with open(report_path, 'r') as f:
        content = f.read()

    items = []

    # Look for ## Open Items section
    pattern = r'## Open Items\s*\n(.*?)(?=\n##|\Z)'
    match = re.search(pattern, content, re.DOTALL)

    if not match:
        return items

    section = match.group(1)

    # Extract dispatch ID from report filename or content
    dispatch_id = report_path.stem
    dispatch_match = re.search(r'Dispatch[- ]ID:\s*(\S+)', content)
    if dispatch_match:
        dispatch_id = dispatch_match.group(1)

    # Extract PR ID from report
    pr_id = None
    pr_match = re.search(r'PR[- ]ID:\s*(\S+)', content)
    if pr_match:
        pr_id = pr_match.group(1)

    # Parse checklist items
    # Format: - [ ] [severity?] Title (details)
    item_pattern = r'^- \[ \]\s*(?:\[(\w+)\])?\s*(.+)$'

    for line in section.split('\n'):
        match = re.match(item_pattern, line.strip())
        if match:
            severity = match.group(1) or 'info'
            text = match.group(2).strip()

            # Normalize severity
            if severity.lower() in ['blocker', 'critical']:
                severity = 'blocker'
            elif severity.lower() in ['warn', 'warning', 'medium']:
                severity = 'warn'
            else:
                severity = 'info'

            items.append({
                'title': text,
                'severity': severity,
                'dispatch_id': dispatch_id,
                'pr_id': pr_id,
                'report_path': str(report_path)
            })

    return items

def add_item_to_tracker(item):
    """Add an item to the open items tracker using the CLI"""
    cmd = [
        'python', str(OPEN_ITEMS_MANAGER),
        'add',
        '--dispatch', item['dispatch_id'],
        '--title', item['title'],
        '--severity', item['severity'],
        '--report', item['report_path']
    ]

    if item['pr_id']:
        cmd.extend(['--pr', item['pr_id']])

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr

def main():
    parser = argparse.ArgumentParser(description="Extract open items from unified reports")
    parser.add_argument('--force', action='store_true',
                       help='Re-process all reports (ignore cache)')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show what would be extracted without adding')
    parser.add_argument('--report', type=str,
                       help='Process specific report file')

    args = parser.parse_args()

    # Load processed cache
    processed = {} if args.force else load_processed()

    # Determine which reports to process
    if args.report:
        report_files = [Path(args.report)]
    else:
        report_files = sorted(REPORTS_DIR.glob("*.md"))

    total_items = 0
    added_items = 0

    for report_path in report_files:
        # Skip if already processed
        file_key = f"{report_path.name}:{report_path.stat().st_mtime}"
        if file_key in processed and not args.force:
            continue

        print(f"📄 Processing: {report_path.name}")

        # Extract items
        items = extract_items_from_report(report_path)

        if not items:
            print(f"   No open items found")
            processed[file_key] = {'count': 0, 'timestamp': datetime.now().isoformat()}
            continue

        print(f"   Found {len(items)} open items")
        total_items += len(items)

        # Add each item
        for item in items:
            if args.dry_run:
                print(f"   [DRY-RUN] Would add: [{item['severity']}] {item['title']}")
            else:
                success, output = add_item_to_tracker(item)
                if success:
                    print(f"   ✅ Added: {item['title']}")
                    added_items += 1
                else:
                    print(f"   ❌ Failed: {item['title']}")
                    print(f"      Error: {output}")

        # Mark as processed
        if not args.dry_run:
            processed[file_key] = {
                'count': len(items),
                'timestamp': datetime.now().isoformat()
            }

    # Save processed cache
    if not args.dry_run:
        save_processed(processed)

        # Generate digest
        if added_items > 0:
            print(f"\n📊 Generating digest...")
            subprocess.run(['python', str(OPEN_ITEMS_MANAGER), 'digest'])

    print(f"\n✅ Extraction complete:")
    print(f"   Total items found: {total_items}")
    if not args.dry_run:
        print(f"   Items added: {added_items}")
    else:
        print(f"   (Dry run - no items actually added)")

if __name__ == "__main__":
    sys.exit(main())
