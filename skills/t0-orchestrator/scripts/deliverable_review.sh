#!/usr/bin/env bash
# deliverable_review.sh
# Read-only helper for open-item and deliverable review workflows.
# Examples:
#   bash .claude/skills/t0-orchestrator/scripts/deliverable_review.sh digest
#   bash .claude/skills/t0-orchestrator/scripts/deliverable_review.sh pr PR-7
#   bash .claude/skills/t0-orchestrator/scripts/deliverable_review.sh can-complete PR-7

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
OPEN_ITEMS_MANAGER="$REPO_ROOT/.claude/vnx-system/scripts/open_items_manager.py"
OPEN_ITEMS_JSON="$REPO_ROOT/.vnx-data/state/open_items.json"

usage() {
    cat <<'USAGE'
Usage:
  deliverable_review.sh digest               Show open-items digest
  deliverable_review.sh open                 List all open items
  deliverable_review.sh pr <PR-ID>           List open items matching a PR
  deliverable_review.sh blockers <PR-ID>     List open blocker/warn items for a PR
  deliverable_review.sh can-complete <PR-ID> Check if blocker/warn items are clear

Examples:
  bash .claude/skills/t0-orchestrator/scripts/deliverable_review.sh digest
  bash .claude/skills/t0-orchestrator/scripts/deliverable_review.sh pr PR-5
USAGE
}

require_manager() {
    if [[ ! -f "$OPEN_ITEMS_MANAGER" ]]; then
        echo "Missing script: $OPEN_ITEMS_MANAGER" >&2
        exit 1
    fi
}

require_json() {
    if [[ ! -f "$OPEN_ITEMS_JSON" ]]; then
        echo "Missing file: $OPEN_ITEMS_JSON" >&2
        exit 1
    fi
}

run_open_items() {
    require_manager
    python3 "$OPEN_ITEMS_MANAGER" "$@"
}

list_pr_items() {
    local pr_id="$1"
    require_json
    jq -r --arg pr "$pr_id" '
        def pr_re($p): "(^|[^0-9A-Z])" + ($p | gsub("-"; "\\\\-")) + "([^0-9]|$)";
        .items[]
        | select(.status == "open")
        | select(
            (.pr_id != null and (.pr_id | ascii_upcase) == ($pr | ascii_upcase))
            or ((.title // "") | test(pr_re($pr); "i"))
          )
        | "\(.id) [\(.severity)] \(.title)"' "$OPEN_ITEMS_JSON"
}

list_pr_blockers() {
    local pr_id="$1"
    require_json
    jq -r --arg pr "$pr_id" '
        def pr_re($p): "(^|[^0-9A-Z])" + ($p | gsub("-"; "\\\\-")) + "([^0-9]|$)";
        .items[]
        | select(.status == "open")
        | select(
            (.pr_id != null and (.pr_id | ascii_upcase) == ($pr | ascii_upcase))
            or ((.title // "") | test(pr_re($pr); "i"))
          )
        | select(.severity == "blocker" or .severity == "warn")
        | "\(.id) [\(.severity)] \(.title)"' "$OPEN_ITEMS_JSON"
}

can_complete_pr() {
    local pr_id="$1"
    require_json
    local count
    count=$(jq -r --arg pr "$pr_id" '
        def pr_re($p): "(^|[^0-9A-Z])" + ($p | gsub("-"; "\\\\-")) + "([^0-9]|$)";
        [ .items[]
          | select(.status == "open")
          | select(
              (.pr_id != null and (.pr_id | ascii_upcase) == ($pr | ascii_upcase))
              or ((.title // "") | test(pr_re($pr); "i"))
            )
          | select(.severity == "blocker" or .severity == "warn")
        ] | length' "$OPEN_ITEMS_JSON")

    if [[ "$count" == "0" ]]; then
        echo "YES: blocker/warn open items cleared for $pr_id"
        return 0
    fi

    echo "NO: $count blocker/warn item(s) still open for $pr_id"
    return 2
}

main() {
    local command="${1:-digest}"

    case "$command" in
        digest)
            run_open_items digest
            ;;
        open)
            run_open_items list --status open
            ;;
        pr)
            [[ $# -lt 2 ]] && { echo "Missing PR-ID" >&2; usage; exit 1; }
            list_pr_items "$2"
            ;;
        blockers)
            [[ $# -lt 2 ]] && { echo "Missing PR-ID" >&2; usage; exit 1; }
            list_pr_blockers "$2"
            ;;
        can-complete)
            [[ $# -lt 2 ]] && { echo "Missing PR-ID" >&2; usage; exit 1; }
            can_complete_pr "$2"
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
