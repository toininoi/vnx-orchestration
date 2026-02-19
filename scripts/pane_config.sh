#!/bin/bash
# Unified Pane Configuration for VNX System
# Single source of truth for pane IDs

# Default pane IDs (used when panes.json is missing or incomplete)
export DEFAULT_T0_PANE="%0"
export DEFAULT_T1_PANE="%1"
export DEFAULT_T2_PANE="%2"
export DEFAULT_T3_PANE="%3"

# Function to get pane ID with consistent fallback
get_pane_id() {
    local terminal="$1"  # T0, T1, T2, or T3
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/vnx_paths.sh"
    local panes_file="${2:-$VNX_STATE_DIR/panes.json}"

    # Normalize terminal name to uppercase
    terminal=$(echo "$terminal" | tr '[:lower:]' '[:upper:]')

    # Try to read from panes.json first
    if [ -f "$panes_file" ]; then
        local pane_id=$(jq -r ".${terminal}.pane_id // empty" "$panes_file" 2>/dev/null)
        if [ -n "$pane_id" ]; then
            echo "$pane_id"
            return 0
        fi
    fi

    # Fall back to defaults
    case "$terminal" in
        T0) echo "$DEFAULT_T0_PANE" ;;
        T1) echo "$DEFAULT_T1_PANE" ;;
        T2) echo "$DEFAULT_T2_PANE" ;;
        T3) echo "$DEFAULT_T3_PANE" ;;
        *) echo "$DEFAULT_T0_PANE" ;;  # Unknown terminal defaults to T0
    esac
}

# Function to get terminal name from pane ID (reverse lookup)
get_terminal_from_pane() {
    local pane_id="$1"  # e.g., %1
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/vnx_paths.sh"
    local panes_file="${2:-$VNX_STATE_DIR/panes.json}"

    # Try to read from panes.json first
    if [ -f "$panes_file" ]; then
        local terminal=$(jq -r "to_entries[] | select(.value.pane_id == \"$pane_id\") | .key" "$panes_file" 2>/dev/null | grep "^T[0-3]$" | head -1)
        if [ -n "$terminal" ]; then
            echo "$terminal"
            return 0
        fi
    fi

    # Fall back to defaults (reverse mapping)
    case "$pane_id" in
        "%0") echo "T0" ;;
        "%1") echo "T1" ;;
        "%2") echo "T2" ;;
        "%3") echo "T3" ;;
        *) echo "UNKNOWN" ;;  # Unknown pane
    esac
}

# Export functions for use in other scripts
export -f get_pane_id
export -f get_terminal_from_pane
