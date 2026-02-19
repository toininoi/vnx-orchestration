#!/bin/bash
# Send single Track B receipt to T0
# Created: 2026-01-06

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vnx_paths.sh"
REPORT_FILE="${REPORT_FILE:-$VNX_REPORTS_DIR/20260106-133800-T2-IMPL-RAG-PIPELINE-ACTIVATION.md}"
RECEIPT_FILE="${RECEIPT_FILE:-$VNX_STATE_DIR/t0_receipts.ndjson}"
APPEND_RECEIPT_SCRIPT="${APPEND_RECEIPT_SCRIPT:-$SCRIPT_DIR/append_receipt.py}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing Track B report: $REPORT_FILE"

# Check if report exists
if [ ! -f "$REPORT_FILE" ]; then
    echo "ERROR: Report file not found: $REPORT_FILE"
    exit 1
fi

# Extract receipt from report using report_parser.py
cd "$SCRIPT_DIR"
python3 report_parser.py "$REPORT_FILE" > /tmp/track_b_receipt.json

if [ -s /tmp/track_b_receipt.json ]; then
    echo "Receipt generated:"
    cat /tmp/track_b_receipt.json | jq .

    # Canonical append path handles locking and idempotency.
    if python3 "$APPEND_RECEIPT_SCRIPT" --receipt-file /tmp/track_b_receipt.json --receipts-file "$RECEIPT_FILE"; then
        echo "Receipt append processed for $RECEIPT_FILE"
    else
        echo "ERROR: append_receipt.py failed for $RECEIPT_FILE"
        exit 1
    fi

    # Find T0 pane
    T0_PANE=$(tmux list-panes -a -F "#{pane_id} #{pane_current_path}" | grep "T0" | awk '{print $1}' | head -1)

    if [ -z "$T0_PANE" ]; then
        # Try alternative method
        T0_PANE=$(tmux list-windows -a -F "#{window_name} #{pane_id}" | grep -E "(T0|orchestrator)" | awk '{print $2}' | head -1)
    fi

    if [ -n "$T0_PANE" ]; then
        echo "Sending receipt notification to T0 at pane $T0_PANE"
        tmux send-keys -t "$T0_PANE" "" C-m
        tmux send-keys -t "$T0_PANE" "# RECEIPT: Track B report available" C-m
        tmux send-keys -t "$T0_PANE" "# Report: 20260106-133800-T2-IMPL-RAG-PIPELINE-ACTIVATION" C-m
        tmux send-keys -t "$T0_PANE" "# Type: implementation" C-m
        tmux send-keys -t "$T0_PANE" "# Summary: RAG pipeline activation complete with lazy initialization" C-m
        tmux send-keys -t "$T0_PANE" "" C-m
        echo "Receipt notification sent to T0"
    else
        echo "WARNING: Could not find T0 pane. Receipt saved but not sent."
        echo "T0 will pick it up on next receipt check."
    fi
else
    echo "ERROR: Failed to generate receipt from report"
    exit 1
fi

echo "Track B receipt processing complete"
