#!/bin/bash
# Receipt Processor Lean Update - Token-Optimized Version
# This snippet shows how to update receipt_processor_v4.sh for lean receipts

# Function to generate lean receipt
generate_lean_receipt() {
    local dispatch_id="$1"
    local terminal="$2"
    local status="$3"
    local gate="$4"
    local event_type="$5"
    local summary="${6:-Task update}"

    # Check if verbose format needed (errors, blockers, first after idle)
    local use_verbose=false
    if [[ "$status" == "error" ]] || [[ "$status" == "blocked" ]] || [[ "$event_type" == "task_failed" ]]; then
        use_verbose=true
    fi

    # Generate timestamp
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Generate lean receipt
    local receipt=""
    if [[ "$use_verbose" == false ]]; then
        # Lean format (default)
        receipt="# 📋 RECEIPT
**ID**: $dispatch_id
**Terminal**: $terminal
**Status**: $status
**Gate**: $gate

$summary

---
*Intelligence hook provides real-time context*"
    else
        # Verbose format (for errors/blockers)
        receipt="# 📋 RECEIPT [${status^^}]
**ID**: $dispatch_id
**Terminal**: $terminal
**Status**: $status
**Gate**: $gate
**Event**: $event_type

## Summary
$summary

## Action Required
Check t0_brief.json for blockers and next steps.

---
*See unified reports for full details*"
    fi

    echo "$receipt"
}

# Function to log minimal NDJSON via canonical helper
log_receipt_ndjson() {
    local dispatch_id="$1"
    local terminal="$2"
    local status="$3"
    local gate="$4"
    local event_type="$5"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=lib/vnx_paths.sh
    source "$script_dir/lib/vnx_paths.sh"

    local receipt_json
    receipt_json=$(
        TIMESTAMP="$timestamp" \
        DISPATCH_ID="$dispatch_id" \
        TERMINAL="$terminal" \
        STATUS="$status" \
        GATE="$gate" \
        EVENT_TYPE="$event_type" \
        python3 - <<'PY'
import json
import os

payload = {
    "timestamp": os.environ["TIMESTAMP"],
    "dispatch_id": os.environ["DISPATCH_ID"],
    "terminal": os.environ["TERMINAL"],
    "status": os.environ["STATUS"],
    "gate": os.environ["GATE"],
    "event_type": os.environ.get("EVENT_TYPE", ""),
}

print(json.dumps(payload, separators=(",", ":"), sort_keys=True))
PY
    )

    printf '%s' "$receipt_json" | python3 "$script_dir/append_receipt.py"
}

# Example usage in receipt_processor_v4.sh:
# Replace the old receipt generation with:
#
# # Generate lean receipt
# local receipt_text=$(generate_lean_receipt "$dispatch_id" "$terminal" "$status" "$gate" "$event_type" "$summary")
#
# # Log to NDJSON
# log_receipt_ndjson "$dispatch_id" "$terminal" "$status" "$gate" "$event_type"
#
# # Send to T0 (tmux)
# echo "$receipt_text" | tmux load-buffer -
# tmux paste-buffer -t vnx:0.0
