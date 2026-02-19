#!/bin/bash
# T0 Brief Query Helper
# Provides simple, safe queries for T0 brief data without complex jq escaping
# Usage: ./query_t0_brief.sh [terminals|gates|receipts|full]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
BRIEF_FILE="$VNX_STATE_DIR/t0_brief.json"

# Ensure brief file exists
if [ ! -f "$BRIEF_FILE" ]; then
    echo "❌ Error: T0 brief file not found: $BRIEF_FILE"
    exit 1
fi

# Parse command
QUERY="${1:-full}"

case "$QUERY" in
    terminals|terminal)
        # Show terminal status (simple, no complex filters)
        cat "$BRIEF_FILE" | jq '.terminals'
        ;;

    gates|next_gates)
        # Show next gates for each track
        cat "$BRIEF_FILE" | jq '.next_gates'
        ;;

    receipts|recent)
        # Show recent receipts
        cat "$BRIEF_FILE" | jq '.recent_receipts'
        ;;

    health|status)
        # Show overall health
        cat "$BRIEF_FILE" | jq '{health, timestamp}'
        ;;

    summary)
        # Show concise summary
        cat "$BRIEF_FILE" | jq '{
            timestamp,
            health,
            terminals: .terminals,
            next_gates: .next_gates,
            recent_count: (.recent_receipts | length)
        }'
        ;;

    full|all)
        # Show everything (formatted)
        cat "$BRIEF_FILE" | jq .
        ;;

    *)
        echo "Usage: $0 [terminals|gates|receipts|health|summary|full]"
        echo ""
        echo "Examples:"
        echo "  $0 terminals  # Show terminal status"
        echo "  $0 gates      # Show next gates"
        echo "  $0 receipts   # Show recent receipts"
        echo "  $0 summary    # Show concise summary"
        exit 1
        ;;
esac
