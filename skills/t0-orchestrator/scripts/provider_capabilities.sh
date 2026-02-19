#!/usr/bin/env bash
# provider_capabilities.sh
# Read-only provider capability helper for dispatch decisions.
# Examples:
#   bash .claude/skills/t0-orchestrator/scripts/provider_capabilities.sh current
#   bash .claude/skills/t0-orchestrator/scripts/provider_capabilities.sh current T1
#   bash .claude/skills/t0-orchestrator/scripts/provider_capabilities.sh matrix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PANES_FILE="$REPO_ROOT/.vnx-data/state/panes.json"

usage() {
    cat <<'USAGE'
Usage:
  provider_capabilities.sh current [T1|T2|T3|T0]
  provider_capabilities.sh matrix
  provider_capabilities.sh rules <provider>

Examples:
  bash .claude/skills/t0-orchestrator/scripts/provider_capabilities.sh current
  bash .claude/skills/t0-orchestrator/scripts/provider_capabilities.sh rules codex_cli
USAGE
}

require_state() {
    if [[ ! -f "$PANES_FILE" ]]; then
        echo "Missing file: $PANES_FILE" >&2
        exit 1
    fi
}

print_matrix() {
    cat <<'MATRIX'
Capability Matrix
-----------------
Provider     Native skill cmd   Fallback Role/Workflow/Context   Thinking mode   Planning mode   MCP
claude_code  Yes                Optional                        Yes             Yes             Yes*
codex_cli    Not guaranteed     Primary pattern                 No              Limited/verify   No
gemini_cli   Not guaranteed     Primary pattern                 No              No              No

* Depends on provider/runtime configuration.
MATRIX
}

print_rules() {
    local provider="$1"

    case "$provider" in
        claude_code)
            cat <<'RULES'
Provider: claude_code
- Skill-first dispatch is supported.
- Mode: thinking/planning can be used when appropriate.
- Requires-Model fields can be used for Claude model routing.
RULES
            ;;
        codex_cli)
            cat <<'RULES'
Provider: codex_cli
- Do not assume native slash-skill invocation.
- Use explicit Role, Workflow, and Context fields.
- Avoid Mode: thinking.
- Planning support is version-dependent; verify before use.
- No MCP in this runtime path.
RULES
            ;;
        gemini_cli)
            cat <<'RULES'
Provider: gemini_cli
- Do not assume native slash-skill invocation.
- Use explicit Role, Workflow, and Context fields.
- Avoid Mode: thinking and Mode: planning.
- Omit model-routing assumptions.
- No MCP in this runtime path.
RULES
            ;;
        *)
            echo "Unknown provider: $provider" >&2
            exit 1
            ;;
    esac
}

show_current() {
    local terminal="${1:-T1}"
    local provider

    provider=$(jq -r --arg terminal "$terminal" '.[$terminal].provider // empty' "$PANES_FILE")
    if [[ -z "$provider" ]]; then
        echo "No provider found for terminal: $terminal" >&2
        exit 1
    fi

    echo "Terminal: $terminal"
    echo "Provider: $provider"
    echo
    print_rules "$provider"
}

main() {
    local command="${1:-current}"

    require_state

    case "$command" in
        current)
            show_current "${2:-T1}"
            ;;
        matrix)
            print_matrix
            ;;
        rules)
            [[ $# -lt 2 ]] && { echo "Missing provider" >&2; usage; exit 1; }
            print_rules "$2"
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
