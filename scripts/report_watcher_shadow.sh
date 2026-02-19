#!/bin/bash

# Report Watcher Service - SHADOW MODE
# =====================================
# Monitors unified_reports directory for new markdown files
# Extracts receipts using report_parser.py
# Writes to SHADOW receipts file for comparison testing
# Part of VNX Unified Reporting System

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
VNX_DIR="$VNX_HOME"
REPORTS_DIR="$VNX_REPORTS_DIR"
RECEIPTS_FILE="$VNX_STATE_DIR/shadow_receipts.ndjson"  # SHADOW FILE
PARSER_SCRIPT="$VNX_DIR/scripts/report_parser_json.py"
PROCESSED_FILE="$VNX_STATE_DIR/shadow_processed_reports.txt"  # SHADOW TRACKING
LOG_FILE="$VNX_LOGS_DIR/shadow_report_watcher.log"  # SHADOW LOG
PID_FILE="$VNX_PIDS_DIR/shadow_report_watcher.pid"  # SHADOW PID

# Create necessary directories and files
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"
touch "$PROCESSED_FILE" "$RECEIPTS_FILE"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SHADOW: $1" >> "$LOG_FILE"
}

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Shadow report watcher already running with PID $OLD_PID"
        exit 1
    fi
fi

# Store PID
echo $$ > "$PID_FILE"

log "=== Shadow Report Watcher Starting ==="
log "Monitoring: $REPORTS_DIR"
log "Output to: $RECEIPTS_FILE"
log "Parser: $PARSER_SCRIPT"

# Add startup metadata
echo "{\"event\":\"shadow_watcher_start\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"mode\":\"shadow\",\"output_file\":\"shadow_receipts.ndjson\"}" >> "$RECEIPTS_FILE"

# Function to process a report
process_report() {
    local report_path="$1"
    local report_name=$(basename "$report_path")

    # Check if already processed
    if grep -q "^$report_name$" "$PROCESSED_FILE" 2>/dev/null; then
        return
    fi

    log "Processing new report: $report_name"

    # Extract receipt using parser
    if [ -f "$PARSER_SCRIPT" ]; then
        # Get receipt from parser (clean JSON output)
        RECEIPT=$(python "$PARSER_SCRIPT" "$report_path" 2>/dev/null)

        if [ ! -z "$RECEIPT" ]; then
            # Add shadow mode indicator
            RECEIPT_WITH_SHADOW=$(echo "$RECEIPT" | jq -c '. + {shadow_mode: true}' 2>/dev/null || echo "$RECEIPT")

            # Write to shadow receipts file
            echo "$RECEIPT_WITH_SHADOW" >> "$RECEIPTS_FILE"
            log "Receipt extracted and written to shadow file"

            # Mark as processed
            echo "$report_name" >> "$PROCESSED_FILE"

            # Log comparison opportunity
            log "COMPARISON_POINT: Report $report_name processed for shadow comparison"
        else
            log "WARNING: No receipt extracted from $report_name"
        fi
    else
        log "ERROR: Parser script not found at $PARSER_SCRIPT"
    fi
}

# Process existing reports first
log "Processing existing reports..."
for report in "$REPORTS_DIR"/*.md; do
    [ -f "$report" ] || continue
    process_report "$report"
done

log "Starting file watch monitoring..."

# Monitor for new reports
if command -v fswatch >/dev/null 2>&1; then
    # Use fswatch if available
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

# Cleanup on exit
trap "rm -f $PID_FILE; log 'Shadow Report watcher stopped'; echo \"{\\\"event\\\":\\\"shadow_watcher_stop\\\",\\\"timestamp\\\":\\\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\\\"}\" >> \"$RECEIPTS_FILE\"" EXIT
