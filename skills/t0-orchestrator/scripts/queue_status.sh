#!/usr/bin/env bash
# queue_status.sh
# Read-only queue/staging/terminal status helper for T0 orchestration.
# Examples:
#   bash .claude/skills/t0-orchestrator/scripts/queue_status.sh summary
#   bash .claude/skills/t0-orchestrator/scripts/queue_status.sh terminals
#   bash .claude/skills/t0-orchestrator/scripts/queue_status.sh staging

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PR_QUEUE_MANAGER="$REPO_ROOT/.claude/vnx-system/scripts/pr_queue_manager.py"
T0_BRIEF="$REPO_ROOT/.vnx-data/state/t0_brief.json"

usage() {
    cat <<'USAGE'
Usage:
  queue_status.sh summary      Show PR queue status + terminal snapshot
  queue_status.sh queue        Show queue counts from t0_brief.json
  queue_status.sh terminals    Show terminal status summary from t0_brief.json
  queue_status.sh staging      Show staged dispatches
  queue_status.sh list         List PR queue entries

Examples:
  bash .claude/skills/t0-orchestrator/scripts/queue_status.sh summary
  bash .claude/skills/t0-orchestrator/scripts/queue_status.sh staging
USAGE
}

require_file() {
    local file_path="$1"
    if [[ ! -f "$file_path" ]]; then
        echo "Missing file: $file_path" >&2
        exit 1
    fi
}

run_pr_queue() {
    if [[ ! -f "$PR_QUEUE_MANAGER" ]]; then
        echo "Missing manager script: $PR_QUEUE_MANAGER" >&2
        exit 1
    fi
    python3 "$PR_QUEUE_MANAGER" "$@"
}

show_queue() {
    require_file "$T0_BRIEF"
    jq -r '.queues | "pending=\(.pending) active=\(.active) conflicts=\(.conflicts) completed_last_hour=\(.completed_last_hour // 0)"' "$T0_BRIEF"
}

show_terminals() {
    require_file "$T0_BRIEF"
    jq -r '.terminals | to_entries[] | "\(.key)=\(.value.status)(\(.value.status_age_seconds // 0)s)"' "$T0_BRIEF"
}

show_summary() {
    echo "== PR Queue =="
    run_pr_queue status
    echo
    echo "== Queue Snapshot =="
    show_queue
    echo
    echo "== Terminals =="
    show_terminals
}

main() {
    local command="${1:-summary}"

    case "$command" in
        summary)
            show_summary
            ;;
        queue)
            show_queue
            ;;
        terminals)
            show_terminals
            ;;
        staging)
            run_pr_queue staging-list
            ;;
        list)
            run_pr_queue list
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: $command" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
