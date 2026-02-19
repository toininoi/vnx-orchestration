#!/bin/bash
# Generate lean receipt format for T0
# Usage: ./generate_lean_receipt.sh <dispatch_id> <terminal> <status> <gate> <summary>

set -euo pipefail

DISPATCH_ID="${1:-unknown}"
TERMINAL="${2:-T?}"
STATUS="${3:-pending}"
GATE="${4:-unknown}"
SUMMARY="${5:-Task update}"

# Generate timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"

# Output lean receipt
cat <<EOF
# 📋 RECEIPT

**ID**: $DISPATCH_ID
**Terminal**: $TERMINAL
**Status**: $STATUS
**Gate**: $GATE

$SUMMARY

---
*See t0_brief.json for full context*
EOF

# Log to NDJSON (minimal data) via canonical helper
RECEIPT_JSON=$(
    TIMESTAMP="$TIMESTAMP" \
    DISPATCH_ID="$DISPATCH_ID" \
    TERMINAL="$TERMINAL" \
    STATUS="$STATUS" \
    GATE="$GATE" \
    SUMMARY="$SUMMARY" \
    python3 - <<'PY'
import json
import os

payload = {
    "timestamp": os.environ["TIMESTAMP"],
    "dispatch_id": os.environ["DISPATCH_ID"],
    "terminal": os.environ["TERMINAL"],
    "status": os.environ["STATUS"],
    "gate": os.environ["GATE"],
    "event_type": "task_update",
    "summary": os.environ.get("SUMMARY", ""),
}

print(json.dumps(payload, separators=(",", ":"), sort_keys=True))
PY
)

printf '%s' "$RECEIPT_JSON" | python3 "$SCRIPT_DIR/append_receipt.py"
