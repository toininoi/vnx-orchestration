#!/bin/bash
# ACK Register Utility - Helper for registering ACK expectations
# Called by dispatcher when sending tasks to terminals

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
STATE_DIR="$VNX_STATE_DIR"
ACK_PENDING_DIR="$STATE_DIR/ack_pending"

# Function to show usage
usage() {
    echo "Usage: $0 <task_id> <track> [cmd_id]"
    echo ""
    echo "Registers an ACK expectation for a dispatched task"
    echo ""
    echo "Arguments:"
    echo "  task_id   - Unique task identifier"
    echo "  track     - Track letter (A, B, or C)"
    echo "  cmd_id    - Optional command identifier"
    echo ""
    echo "Example:"
    echo "  $0 A3-2_webvitals A abc123-def456"
    exit 1
}

# Validate arguments
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
fi

TASK_ID="$1"
TRACK="$2"
CMD_ID="${3:-}"

# Validate track
if [[ ! "$TRACK" =~ ^[ABC]$ ]]; then
    echo "ERROR: Track must be A, B, or C. Got: $TRACK"
    exit 1
fi

# Validate task_id
if [ -z "$TASK_ID" ]; then
    echo "ERROR: task_id cannot be empty"
    exit 1
fi

# Create pending directory if it doesn't exist
mkdir -p "$ACK_PENDING_DIR"

# Create pending file for ACK dispatcher to pick up
PENDING_FILE="$ACK_PENDING_DIR/${TASK_ID}_$(date +%s).pending"

cat > "$PENDING_FILE" <<EOF
task_id=$TASK_ID
track=$TRACK
cmd_id=$CMD_ID
registered_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
registered_by=$$
EOF

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ACK expectation registered: $TASK_ID (Track $TRACK)"

# Optionally wait a moment for ACK dispatcher to pick it up
sleep 0.5

if [ ! -f "$PENDING_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ACK expectation processed by ACK dispatcher"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ACK expectation pending (file: $(basename "$PENDING_FILE"))"
fi
