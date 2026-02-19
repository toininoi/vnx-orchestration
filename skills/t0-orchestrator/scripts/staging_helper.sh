#!/bin/bash
# Staging Dispatch Helper for T0
# Quick commands for staging workflow operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VNX_ROOT="$(cd "$SCRIPT_DIR/../../../vnx-system" && pwd)"
PR_QUEUE_MANAGER="$VNX_ROOT/scripts/pr_queue_manager.py"
STAGING_DIR="$VNX_ROOT/dispatches/staging"
QUEUE_DIR="$VNX_ROOT/dispatches/queue"
REJECTED_DIR="$VNX_ROOT/dispatches/rejected"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
    cat << EOF
${BLUE}Staging Dispatch Helper${NC}
Quick commands for T0 staging workflow operations

${YELLOW}Usage:${NC}
  $0 list                           # List all staging dispatches
  $0 show <dispatch-id>             # Show dispatch details
  $0 patch <dispatch-id> <field> <value>  # Patch dispatch field
  $0 promote <dispatch-id>          # Promote to queue
  $0 reject <dispatch-id> [reason]  # Reject dispatch
  $0 audit [n]                      # Show last n audit entries (default: 10)
  $0 status                         # Show staging/queue/rejected counts

${YELLOW}Examples:${NC}
  $0 list
  $0 show 20260204-143000-pr-1-A
  $0 patch 20260204-143000-pr-1-A role backend-developer
  $0 promote 20260204-143000-pr-1-A
  $0 reject 20260204-143000-pr-1-A "wrong-track"
  $0 audit 20

${YELLOW}Whitelisted Patch Fields:${NC}
  role, track, terminal, priority, cognition, reason, pr-id

EOF
    exit 0
}

# List staging dispatches
list_staging() {
    echo -e "${BLUE}Staging Dispatches:${NC}"

    if [[ ! -d "$STAGING_DIR" ]] || [[ -z "$(ls -A "$STAGING_DIR" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}  No dispatches in staging${NC}"
        return
    fi

    for file in "$STAGING_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        dispatch_id=$(basename "$file" .md)

        # Extract title from file
        title=$(grep "^# " "$file" | head -1 | sed 's/^# //')

        echo -e "  ${GREEN}●${NC} $dispatch_id"
        [[ -n "$title" ]] && echo -e "    ${title}"
    done
}

# Show dispatch
show_dispatch() {
    local dispatch_id="$1"
    python3 "$PR_QUEUE_MANAGER" show "$dispatch_id"
}

# Patch dispatch
patch_dispatch() {
    local dispatch_id="$1"
    local field="$2"
    local value="$3"

    python3 "$PR_QUEUE_MANAGER" patch "$dispatch_id" --"$field" "$value"
}

# Promote dispatch
promote_dispatch() {
    local dispatch_id="$1"
    python3 "$PR_QUEUE_MANAGER" promote "$dispatch_id"
}

# Reject dispatch
reject_dispatch() {
    local dispatch_id="$1"
    local reason="${2:-unspecified}"

    python3 "$PR_QUEUE_MANAGER" reject "$dispatch_id" --reason "$reason"
}

# Show audit log
show_audit() {
    local count="${1:-10}"
    local audit_log="$VNX_ROOT/state/dispatch_audit.jsonl"

    if [[ ! -f "$audit_log" ]]; then
        echo -e "${YELLOW}No audit log found${NC}"
        return
    fi

    echo -e "${BLUE}Last $count Audit Entries:${NC}"
    tail -n "$count" "$audit_log" | while IFS= read -r line; do
        # Parse JSON and format
        action=$(echo "$line" | python3 -c "import sys, json; print(json.load(sys.stdin).get('action', 'unknown'))")
        timestamp=$(echo "$line" | python3 -c "import sys, json; print(json.load(sys.stdin).get('timestamp', 'unknown'))")
        dispatch_id=$(echo "$line" | python3 -c "import sys, json; print(json.load(sys.stdin).get('dispatch_id', 'unknown'))")

        case "$action" in
            dispatch_created)
                echo -e "  ${GREEN}✓${NC} $timestamp - Created: $dispatch_id"
                ;;
            dispatch_promoted)
                echo -e "  ${BLUE}→${NC} $timestamp - Promoted: $dispatch_id"
                ;;
            dispatch_rejected)
                echo -e "  ${RED}✗${NC} $timestamp - Rejected: $dispatch_id"
                ;;
            dispatch_patched)
                echo -e "  ${YELLOW}✎${NC} $timestamp - Patched: $dispatch_id"
                ;;
            *)
                echo -e "  ${NC}•${NC} $timestamp - $action: $dispatch_id"
                ;;
        esac
    done
}

# Show status
show_status() {
    local staging_count=0
    local queue_count=0
    local rejected_count=0

    [[ -d "$STAGING_DIR" ]] && staging_count=$(ls -1 "$STAGING_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    [[ -d "$QUEUE_DIR" ]] && queue_count=$(ls -1 "$QUEUE_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    [[ -d "$REJECTED_DIR" ]] && rejected_count=$(ls -1 "$REJECTED_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')

    echo -e "${BLUE}Dispatch Status:${NC}"
    echo -e "  ${YELLOW}Staging:${NC}  $staging_count"
    echo -e "  ${GREEN}Queue:${NC}    $queue_count"
    echo -e "  ${RED}Rejected:${NC} $rejected_count"
}

# Main
main() {
    [[ $# -eq 0 ]] && usage

    local command="$1"
    shift

    case "$command" in
        list)
            list_staging
            ;;
        show)
            [[ $# -lt 1 ]] && { echo -e "${RED}Error: dispatch-id required${NC}"; exit 1; }
            show_dispatch "$1"
            ;;
        patch)
            [[ $# -lt 3 ]] && { echo -e "${RED}Error: dispatch-id, field, and value required${NC}"; exit 1; }
            patch_dispatch "$1" "$2" "$3"
            ;;
        promote)
            [[ $# -lt 1 ]] && { echo -e "${RED}Error: dispatch-id required${NC}"; exit 1; }
            promote_dispatch "$1"
            ;;
        reject)
            [[ $# -lt 1 ]] && { echo -e "${RED}Error: dispatch-id required${NC}"; exit 1; }
            reject_dispatch "$@"
            ;;
        audit)
            show_audit "${1:-10}"
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            usage
            ;;
    esac
}

main "$@"
