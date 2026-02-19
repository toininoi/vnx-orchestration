#!/usr/bin/env python3
"""
Repair Corrupted Index.ndjson
==============================
Purpose: Fix truncated and pretty-printed JSON entries in report index
Strategy: Buffer accumulation + JSON validation

Author: T-MANAGER
Date: 2026-01-11
Version: 1.0
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

# Configuration
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))
try:
    from vnx_paths import ensure_env
except Exception as exc:
    raise SystemExit(f"Failed to load vnx_paths: {exc}")

PATHS = ensure_env()
INDEX_PATH = Path(PATHS["VNX_REPORTS_DIR"]) / "index.ndjson"


def repair_index():
    """
    Repair corrupted index.ndjson by:
    1. Creating timestamped backup
    2. Accumulating multi-line JSON fragments
    3. Validating each complete JSON object
    4. Writing valid entries as single-line NDJSON
    """

    if not os.path.exists(INDEX_PATH):
        print(f"Error: Index file not found at {INDEX_PATH}")
        return False

    # Create backup
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    backup_path = f"{INDEX_PATH}.backup.{timestamp}"

    print("=" * 80)
    print("Index Repair Script")
    print("=" * 80)
    print(f"Input: {INDEX_PATH}")
    print(f"Backup: {backup_path}")
    print("")

    with open(INDEX_PATH, 'r') as f:
        original_content = f.read()

    with open(backup_path, 'w') as f:
        f.write(original_content)

    print(f"✓ Backup created ({len(original_content)} bytes)")
    print("")

    # Parse and repair
    valid_entries = []
    buffer = ""
    line_num = 0
    skipped_lines = []

    print("Processing entries...")

    with open(INDEX_PATH, 'r') as f:
        for line in f:
            line_num += 1
            stripped = line.strip()

            if not stripped:
                continue  # Skip empty lines

            # Add to buffer
            buffer += stripped

            # Try to parse accumulated buffer
            try:
                entry = json.loads(buffer)
                valid_entries.append(entry)
                print(f"  ✓ Line {line_num}: Valid entry")
                buffer = ""  # Reset buffer on success
            except json.JSONDecodeError as e:
                # Incomplete JSON - continue accumulating
                buffer += " "  # Add space between accumulated lines
                # Only log if this looks like it should be complete
                if stripped.endswith('}') or stripped.endswith(']'):
                    skipped_lines.append((line_num, str(e)))
                continue

    # Check for remaining buffer (incomplete entry at end)
    if buffer.strip():
        print(f"  ⚠️  Warning: Incomplete entry at end of file (discarded)")
        print(f"      Buffer: {buffer[:100]}...")
        skipped_lines.append((line_num + 1, "Incomplete JSON at EOF"))

    print("")
    print("Repair Statistics:")
    print(f"  - Original lines: {line_num}")
    print(f"  - Valid entries: {len(valid_entries)}")
    print(f"  - Skipped/Repaired: {len(skipped_lines)}")

    if skipped_lines:
        print("")
        print("Skipped Lines (first 5):")
        for line_no, error in skipped_lines[:5]:
            print(f"  - Line {line_no}: {error}")

    # Write repaired index
    temp_path = f"{INDEX_PATH}.tmp"

    try:
        with open(temp_path, 'w') as f:
            for entry in valid_entries:
                # Write as compact single-line JSON
                f.write(json.dumps(entry, separators=(',', ':')) + '\n')

        # Atomic rename
        os.rename(temp_path, INDEX_PATH)

        print("")
        print(f"✓ Repair complete: {INDEX_PATH}")
        print(f"✓ Backup saved: {backup_path}")
        print("")
        print("Next Steps:")
        print("  1. Verify repair: python3 build_t0_tags_digest.py")
        print("     (Should show '0 skipped')")
        print(f"  2. Check digest: cat {PATHS['VNX_STATE_DIR']}/t0_tags_digest.json | jq '.top_tags_7d[0]'")
        print("     (Should show real file paths, not 'unknown')")
        print("")

        return True

    except Exception as e:
        print(f"Error writing repaired index: {e}")
        if os.path.exists(temp_path):
            os.remove(temp_path)
        return False


def validate_repair():
    """
    Validate repaired index by parsing every line
    """
    print("Validating repaired index...")

    if not os.path.exists(INDEX_PATH):
        print("Error: Index file not found")
        return False

    valid = 0
    invalid = 0

    with open(INDEX_PATH, 'r') as f:
        for line_num, line in enumerate(f, start=1):
            if line.strip():
                try:
                    json.loads(line)
                    valid += 1
                except json.JSONDecodeError as e:
                    invalid += 1
                    print(f"  ✗ Line {line_num}: {e}")

    print(f"Validation Results:")
    print(f"  - Valid entries: {valid}")
    print(f"  - Invalid entries: {invalid}")

    if invalid == 0:
        print("  ✓ Index is healthy")
        return True
    else:
        print("  ✗ Index still has issues")
        return False


def main():
    """Main entry point"""
    success = repair_index()

    if success:
        print("─" * 80)
        validate_repair()

    return 0 if success else 1


if __name__ == '__main__':
    exit(main())
