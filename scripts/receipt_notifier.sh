#!/bin/bash
# DEPRECATED: receipt_notifier replaced by receipt_processor_v4.sh
# Exit immediately to prevent duplicate receipts
exit 0

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
VNX_DIR="$VNX_HOME"
STATE_DIR="$VNX_STATE_DIR"
REPORTS_DIR="$VNX_REPORTS_DIR"
LOG_FILE="$VNX_LOGS_DIR/receipt_notifier.log"
PROCESSED_FILE="$STATE_DIR/processed_receipts.txt"
RECEIPTS_FILE="$STATE_DIR/t0_receipts.ndjson"
PARSER_SCRIPT="$VNX_DIR/scripts/report_parser.py"
APPEND_RECEIPT_SCRIPT="$VNX_DIR/scripts/append_receipt.py"
FOOTER_FILE="$VNX_DIR/templates/footers/t0_action_request_autonomous.md"

# Fallback chain: autonomous → enhanced → original
if [ ! -f "$FOOTER_FILE" ]; then
    FOOTER_FILE="$VNX_DIR/templates/footers/t0_action_request_enhanced.md"
fi
if [ ! -f "$FOOTER_FILE" ]; then
    FOOTER_FILE="$VNX_DIR/templates/footers/t0_action_request.md"
fi

# Bulletproof singleton management using flock
source "$VNX_DIR/scripts/singleton_enforcer.sh"
enforce_singleton "receipt_notifier" "$LOG_FILE" "$SCRIPT_DIR/receipt_notifier.sh"

# Set up cleanup trap
trap "echo '[INFO] Receipt notifier shutting down' >> $LOG_FILE; vnx_proc_log_event \"$LOG_FILE\" \"receipt_notifier\" \"stop\" \"$$\" \"shutdown\"" EXIT INT TERM

# Source pane configuration
source "$VNX_DIR/scripts/pane_config.sh"

# DON'T cache T0 pane - will be read fresh on each notification
echo "[RECEIPT_NOTIFIER_V3] Starting enhanced receipt monitoring..."
echo "[RECEIPT_NOTIFIER_V3] Will read T0 pane dynamically from panes.json on each notification"
echo "[RECEIPT_NOTIFIER_V3] Using parser: $PARSER_SCRIPT"

# Initialize processed file
touch "$PROCESSED_FILE"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] RECEIPT_V3: $1" >> "$LOG_FILE"
}

# Function to enrich completion receipts with system state
enrich_with_system_state() {
    local RECEIPT="$1"

    # Only enrich completion receipts (task_complete, task_failed)
    local RECEIPT_TYPE=$(echo "$RECEIPT" | jq -r '.event_type // .type // ""')
    if [[ "$RECEIPT_TYPE" != "task_complete" ]] && [[ "$RECEIPT_TYPE" != "task_failed" ]]; then
        echo "$RECEIPT"
        return
    fi

    # Canonical enrichment:
    # 1) primary terminal context from terminal_state.json (+ reconciler fallback)
    # 2) orchestration context from t0_brief.json as fallback
    local SYSTEM_STATE
    SYSTEM_STATE=$(python3 "$SCRIPT_DIR/lib/canonical_state_views.py" \
        --state-dir "$STATE_DIR" \
        notifier-system-state 2>/dev/null || echo "")

    if [ -z "$SYSTEM_STATE" ] || [ "$SYSTEM_STATE" = "null" ] || ! echo "$SYSTEM_STATE" | jq -e . >/dev/null 2>&1; then
        log "WARNING: Failed to build canonical system_state payload, skipping enrichment"
        echo "$RECEIPT"
        return
    fi

    # Add system_state to receipt
    local ENRICHED=$(echo "$RECEIPT" | jq -c \
        --argjson state "$SYSTEM_STATE" \
        '. + {system_state: $state}' 2>/dev/null || echo "$RECEIPT")

    log "System state enrichment added to $RECEIPT_TYPE receipt"
    echo "$ENRICHED"
}

log "=== Receipt Notifier V3 Starting ==="
log "Monitoring: $REPORTS_DIR"
log "Output to: $RECEIPTS_FILE"
log "Parser: $PARSER_SCRIPT"
vnx_proc_log_event "$LOG_FILE" "receipt_notifier" "start" "$$" "startup"

# Function to process a report and generate enhanced receipt
process_report() {
    local report_path="$1"
    local report_name=$(basename "$report_path")

    # Calculate hash to avoid duplicates
    local REPORT_HASH=$(echo "$report_name" | sha256sum | cut -d' ' -f1)

    # ATOMIC CHECK-AND-SET using mkdir (atomic on macOS) to prevent race conditions
    local LOCK_DIR="/tmp/vnx-receipt-locks/${REPORT_HASH}"

    # Ensure parent directory exists (non-atomic, but safe)
    mkdir -p "/tmp/vnx-receipt-locks" 2>/dev/null

    # Try to create lock directory atomically (without -p flag = atomic operation)
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        # Lock already exists - another process is handling this report
        log "Report already being processed by another instance: $report_name"
        return 0
    fi

    # We got the lock - set up cleanup trap
    trap "rm -rf '$LOCK_DIR'" RETURN

    # Check if already processed (inside lock)
    if grep -q "$REPORT_HASH" "$PROCESSED_FILE" 2>/dev/null; then
        log "Report already processed (detected in lock): $report_name"
        return 0
    fi

    # Mark as processed immediately (inside lock, before actual processing)
    echo "$REPORT_HASH" >> "$PROCESSED_FILE"
    log "Acquired processing lock for: $report_name"

    # If we got here, we have exclusive rights to process this report
    log "Processing new report: $report_name"

    # Extract enhanced receipt using report_parser.py
    if [ -f "$PARSER_SCRIPT" ]; then
        # Get receipt from parser (clean JSON output)
        RECEIPT=$(python3 "$PARSER_SCRIPT" "$report_path" 2>/dev/null)

        if [ ! -z "$RECEIPT" ] && [ "$RECEIPT" != "null" ]; then
            # Double-check: verify receipt doesn't already exist in t0_receipts.ndjson
            # This prevents duplicates if processed_receipts.txt gets cleared/reset
            REPORT_PATH_CHECK=$(echo "$RECEIPT" | jq -r '.report_path // ""')
            if [ ! -z "$REPORT_PATH_CHECK" ] && grep -q "\"report_path\":\"$REPORT_PATH_CHECK\"" "$RECEIPTS_FILE" 2>/dev/null; then
                log "Receipt already exists in t0_receipts.ndjson, skipping: $report_name"
                # Already marked as processed in the lock above
                return
            fi

            # Ensure shadow_mode is set to true
            RECEIPT_ENHANCED=$(echo "$RECEIPT" | jq -c '. + {shadow_mode: true}' 2>/dev/null || echo "$RECEIPT")

            # Enrich completion receipts with system state from t0_brief.json
            RECEIPT_ENHANCED=$(enrich_with_system_state "$RECEIPT_ENHANCED")

            # Write via canonical append helper (lock + validation + idempotency).
            if printf '%s\n' "$RECEIPT_ENHANCED" | python3 "$APPEND_RECEIPT_SCRIPT" 2>>"$LOG_FILE"; then
                log "Enhanced receipt generated and written"
            else
                log "ERROR: append_receipt.py failed for $report_name"
                return 1
            fi

            # Already marked as processed in the lock above (line 93)

            # Notify T0 with enhanced receipt
            notify_t0_enhanced "$RECEIPT_ENHANCED"
        else
            log "WARNING: No receipt extracted from $report_name"
        fi
    else
        log "ERROR: Parser script not found at $PARSER_SCRIPT"
    fi
}

# Function to notify T0 about an enhanced receipt
notify_t0_enhanced() {
    local RECEIPT="$1"

    # Parse enhanced receipt fields
    TRACK=$(echo "$RECEIPT" | jq -r '.track // "unknown"' 2>/dev/null)
    TERMINAL=$(echo "$RECEIPT" | jq -r '.terminal // "unknown"' 2>/dev/null)
    TYPE=$(echo "$RECEIPT" | jq -r '.type // "UNKNOWN"' 2>/dev/null)
    GATE=$(echo "$RECEIPT" | jq -r '.gate // "unknown"' 2>/dev/null)
    STATUS=$(echo "$RECEIPT" | jq -r '.status // "unknown"' 2>/dev/null)
    SUMMARY=$(echo "$RECEIPT" | jq -r '.summary // "No summary"' 2>/dev/null)
    TITLE=$(echo "$RECEIPT" | jq -r '.title // ""' 2>/dev/null)
    CONFIDENCE=$(echo "$RECEIPT" | jq -r '.confidence // 0.5' 2>/dev/null)
    DISPATCH_ID=$(echo "$RECEIPT" | jq -r '.dispatch_id // "unknown"' 2>/dev/null)
    REPORT_PATH=$(echo "$RECEIPT" | jq -r '.report_path // ""' 2>/dev/null)

    # Extract tags
    ISSUE_TAGS=$(echo "$RECEIPT" | jq -r '.tags.issues[]? // empty' 2>/dev/null | tr '\n' ' ')
    COMPONENT_TAGS=$(echo "$RECEIPT" | jq -r '.tags.components[]? // empty' 2>/dev/null | tr '\n' ' ')
    SOLUTION_TAGS=$(echo "$RECEIPT" | jq -r '.tags.solutions[]? // empty' 2>/dev/null | tr '\n' ' ')

    # Extract dependencies
    DEP_TRACKS=$(echo "$RECEIPT" | jq -r '.dependencies.tracks[]? // empty' 2>/dev/null | tr '\n' ', ')
    DEP_BLOCKING=$(echo "$RECEIPT" | jq -r '.dependencies.blocking // false' 2>/dev/null)
    DEP_RISK=$(echo "$RECEIPT" | jq -r '.dependencies.risk_level // "unknown"' 2>/dev/null)

    # Extract metrics
    PERF_METRICS=$(echo "$RECEIPT" | jq -r '.metrics.performance | to_entries[] | "\(.key): \(.value)"' 2>/dev/null | tr '\n' ', ')
    QUALITY_METRICS=$(echo "$RECEIPT" | jq -r '.metrics.quality | to_entries[] | "\(.key): \(.value)"' 2>/dev/null | tr '\n' ', ')

    log "Notifying T0: Track=$TRACK, Type=$TYPE, Gate=$GATE, Status=$STATUS"

    # Determine next action based on status
    NEXT_ACTION=""
    case "$STATUS" in
        "success")
            NEXT_ACTION="Progress to next gate"
            ;;
        "blocked")
            NEXT_ACTION="Resolve blocker or switch tracks"
            ;;
        "fail")
            NEXT_ACTION="Investigate failure and retry"
            ;;
        "partial_success")
            NEXT_ACTION="Review partial results and complete"
            ;;
        *)
            NEXT_ACTION="Analyze situation"
            ;;
    esac

    # Create notification message for T0
    # Special handling for ACK/task_started receipts - ultra-minimal for user confirmation only
    if [[ "$TYPE" == "task_started" ]] || [[ "$TYPE" =~ "ack" ]]; then
        NOTIFICATION="# ✅ Task Accepted - $TERMINAL

**Dispatch ID**: $DISPATCH_ID"
    else
        # Full notification for completion receipts with terminal status
        # Extract system_state from enriched receipt
        local T1_ST T2_ST T3_ST QUEUE_PENDING QUEUE_ACTIVE GATES_A GATES_B GATES_C
        T1_ST=$(echo "$RECEIPT" | jq -r '.system_state.terminals.T1.status // "?"' 2>/dev/null)
        T2_ST=$(echo "$RECEIPT" | jq -r '.system_state.terminals.T2.status // "?"' 2>/dev/null)
        T3_ST=$(echo "$RECEIPT" | jq -r '.system_state.terminals.T3.status // "?"' 2>/dev/null)
        QUEUE_PENDING=$(echo "$RECEIPT" | jq -r '.system_state.queues.pending // 0' 2>/dev/null)
        QUEUE_ACTIVE=$(echo "$RECEIPT" | jq -r '.system_state.queues.active // 0' 2>/dev/null)
        GATES_A=$(echo "$RECEIPT" | jq -r '.system_state.next_gates.A // "?"' 2>/dev/null)
        GATES_B=$(echo "$RECEIPT" | jq -r '.system_state.next_gates.B // "?"' 2>/dev/null)
        GATES_C=$(echo "$RECEIPT" | jq -r '.system_state.next_gates.C // "?"' 2>/dev/null)

        NOTIFICATION="📨 RECEIPT:$TERMINAL:$STATUS | ID: $DISPATCH_ID | Next: $NEXT_ACTION | Report: $REPORT_PATH
📊 STATE: T1=$T1_ST T2=$T2_ST T3=$T3_ST | Queue: pending=$QUEUE_PENDING active=$QUEUE_ACTIVE | Gates: A=$GATES_A B=$GATES_B C=$GATES_C"
    fi

    # Get T0 pane FRESH from panes.json (handle dynamic pane changes after restarts)
    local T0_PANE=$(get_pane_id "t0" "$STATE_DIR/panes.json")

    # Send to T0 pane using direct paste (original VNX method)
    if [ ! -z "$T0_PANE" ]; then
        log "Sending to T0 pane: $T0_PANE (read fresh from panes.json)"

        # Send notification directly to T0 pane using tmux buffer
        echo "$NOTIFICATION" | tmux load-buffer -
        tmux paste-buffer -t "$T0_PANE" 2>&1 | while read line; do
            log "tmux output: $line"
        done

        # Longer delay to ensure paste completes before Enter
        sleep 1

        # Press Enter to submit the notification (send twice to handle bracketed paste)
        tmux send-keys -t "$T0_PANE" Enter 2>&1 | while read line; do
            log "tmux output: $line"
        done
        sleep 0.3
        tmux send-keys -t "$T0_PANE" Enter 2>&1 | while read line; do
            log "tmux output: $line"
        done

        log "✅ Notification successfully sent to T0 pane: $T0_PANE"
    else
        log "❌ ERROR: T0 pane not found in panes.json, notification not delivered"
    fi
}

# Mark all existing reports as already processed on startup (prevent flooding)
# Only NEW reports arriving after startup should be processed
EXISTING_COUNT=0
for report in "$REPORTS_DIR"/*.md; do
    [ -f "$report" ] || continue
    report_name=$(basename "$report")
    REPORT_HASH=$(echo "$report_name" | sha256sum | cut -d' ' -f1)
    if ! grep -q "$REPORT_HASH" "$PROCESSED_FILE" 2>/dev/null; then
        echo "$REPORT_HASH" >> "$PROCESSED_FILE"
        EXISTING_COUNT=$((EXISTING_COUNT + 1))
    fi
done
log "Startup: marked $EXISTING_COUNT existing reports as processed (skipped)"

log "Starting file watch monitoring..."

# Monitor for new reports
if command -v fswatch >/dev/null 2>&1; then
    # Use fswatch if available
    log "Using fswatch for file monitoring"
    fswatch -0 "$REPORTS_DIR" | while IFS= read -r -d '' path; do
        if [[ "$path" == *.md ]]; then
            process_report "$path"
        fi
    done
else
    # Fallback to polling
    log "fswatch not found, using polling mode"
    while true; do
        for report in "$REPORTS_DIR"/*.md; do
            [ -f "$report" ] || continue
            process_report "$report"
        done
        sleep 5
    done
fi
