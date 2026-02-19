#!/bin/bash

# Dispatch ACK Watcher - SHADOW MODE
# ====================================
# Monitors dispatches moving from queue to completed
# Automatically starts heartbeat ACK monitoring for each dispatch
# SHADOW MODE - Testing automated ACK detection in parallel

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
# shellcheck source=lib/process_lifecycle.sh
source "$SCRIPT_DIR/lib/process_lifecycle.sh"
VNX_DIR="$VNX_HOME"
STATE_DIR="$VNX_STATE_DIR"
QUEUE_DIR="$VNX_DISPATCH_DIR/queue"
COMPLETED_DIR="$VNX_DISPATCH_DIR/completed"
LOG_FILE="$VNX_LOGS_DIR/dispatch_ack_watcher.log"  # Production LOG
PID_FILE="$VNX_PIDS_DIR/dispatch_ack_watcher.pid"  # Production PID
MONITOR_SCRIPT="$VNX_HOME/scripts/heartbeat_ack_monitor.py"
PROC_NAME="dispatch_ack_watcher"
PROC_FINGERPRINT="$(vnx_proc_realpath "$SCRIPT_DIR/dispatch_ack_watcher.sh")"

# Track dispatches we're monitoring
TRACKING_FILE="$STATE_DIR/ack_tracking.json"

# Create necessary directories
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")" "$STATE_DIR"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Initialize tracking file if it doesn't exist
init_tracking() {
    if [ ! -f "$TRACKING_FILE" ]; then
        echo "{}" > "$TRACKING_FILE"
    fi
}

# Check if dispatch is already being tracked
is_tracked() {
    local dispatch_id="$1"
    jq -e ".\"$dispatch_id\"" "$TRACKING_FILE" > /dev/null 2>&1
    return $?
}

# Add dispatch to tracking
add_tracking() {
    local dispatch_id="$1"
    local terminal="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update tracking file
    jq ". + {\"$dispatch_id\": {\"terminal\": \"$terminal\", \"started\": \"$timestamp\", \"status\": \"monitoring\"}}" "$TRACKING_FILE" > "$TRACKING_FILE.tmp"
    mv "$TRACKING_FILE.tmp" "$TRACKING_FILE"
}

# Extract terminal from dispatch log
get_dispatch_terminal() {
    local dispatch_id="$1"

    # Check recent dispatcher logs for this dispatch
    local log_entry=$(grep "$dispatch_id" "$VNX_LOGS_DIR/dispatcher.log" 2>/dev/null | tail -1)

    # Try to extract terminal from log
    if [[ "$log_entry" =~ terminal[[:space:]]([T][0-9]) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$log_entry" =~ vnx-terminal:([T][0-9]) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        # Fallback: check dispatch content for TARGET
        local dispatch_file="$COMPLETED_DIR/${dispatch_id}.md"
        if [ -f "$dispatch_file" ]; then
            local target=$(grep -o 'TARGET:[A-C]' "$dispatch_file" | head -1 | cut -d: -f2)
            case "$target" in
                A) echo "T1" ;;
                B) echo "T2" ;;
                C) echo "T3" ;;
                *) echo "unknown" ;;
            esac
        else
            echo "unknown"
        fi
    fi
}

# Start ACK monitoring for a dispatch
start_ack_monitoring() {
    local dispatch_id="$1"
    local terminal="$2"

    # Extract task ID from dispatch if available
    local dispatch_file="$COMPLETED_DIR/${dispatch_id}.md"
    local task_id="$dispatch_id"  # Default to dispatch ID

    if [ -f "$dispatch_file" ]; then
        # Try to extract task ID from dispatch content
        local extracted_task=$(grep -i "task.*id\|task:" "$dispatch_file" 2>/dev/null | head -1 | sed 's/.*:\s*//')
        if [ ! -z "$extracted_task" ]; then
            task_id="$extracted_task"
        fi
    fi

    log "Starting ACK monitor: dispatch=$dispatch_id, terminal=$terminal, task=$task_id"

    # Start the Python heartbeat monitor in background - SHADOW MODE
    # NOW PROMOTED TO PRODUCTION - Write directly to t0_receipts.ndjson
    RECEIPT_FILE="$STATE_DIR/t0_receipts.ndjson" python3 "$MONITOR_SCRIPT" --stdin <<EOF &
{
    "dispatch_id": "$dispatch_id",
    "terminal": "$terminal",
    "task_id": "$task_id",
    "sent_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    local monitor_pid=$!
    log "ACK monitor started with PID $monitor_pid for $dispatch_id"

    # Track this dispatch
    add_tracking "$dispatch_id" "$terminal"
}

# Monitor for new completed dispatches
monitor_completed() {
    log "Monitoring completed directory for new dispatches..."

    while true; do
        # Get list of completed dispatches
        for dispatch_file in "$COMPLETED_DIR"/*.md; do
            [ -f "$dispatch_file" ] || continue

            local dispatch_id=$(basename "$dispatch_file" .md)

            # Check if we're already tracking this dispatch
            if ! is_tracked "$dispatch_id"; then
                # New dispatch detected!
                log "New completed dispatch detected: $dispatch_id"

                # Get terminal for this dispatch
                local terminal=$(get_dispatch_terminal "$dispatch_id")

                if [ "$terminal" != "unknown" ]; then
                    # Start ACK monitoring
                    start_ack_monitoring "$dispatch_id" "$terminal"
                else
                    log "WARNING: Could not determine terminal for $dispatch_id"
                fi
            fi
        done

        # Wait before next check
        sleep 2
    done
}

# Cleanup function
cleanup() {
    log "Dispatch ACK watcher shutting down..."
    vnx_proc_log_event "$LOG_FILE" "$PROC_NAME" "stop" "$$" "shutdown"
    rm -f "$PID_FILE" "${PID_FILE}.fingerprint"
    rm -rf "$VNX_LOCKS_DIR/${PROC_NAME}.lock"
    exit 0
}

# Main execution
main() {
    # Enforce singleton - kill any existing instances
    if ! vnx_proc_acquire_lock "$PROC_NAME" "$PROC_FINGERPRINT" "$LOG_FILE" "stop_existing" "singleton_start"; then
        log "[SINGLETON] Another instance is already running"
        exit 0
    fi

    # Store PID
    echo $$ > "$PID_FILE"
    echo "$PROC_FINGERPRINT" > "${PID_FILE}.fingerprint"

    # Set up signal handlers
    trap cleanup SIGTERM SIGINT

    log "=== Dispatch ACK Watcher Starting ==="
    log "PID: $$"
    log "Monitoring: $COMPLETED_DIR"
    log "ACK Monitor: $MONITOR_SCRIPT"
    vnx_proc_log_event "$LOG_FILE" "$PROC_NAME" "start" "$$" "startup"

    # Initialize tracking
    init_tracking

    # Start monitoring
    monitor_completed
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
