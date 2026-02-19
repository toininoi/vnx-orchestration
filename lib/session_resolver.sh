#!/bin/bash
# .claude/vnx-system/lib/session_resolver.sh
# Session metadata resolution helper functions for VNX receipt system
#
# Purpose: Resolve session_id, model, and provider in a provider-agnostic way
# Usage: source this file and call resolve_session_id() and resolve_model_provider()
# Output: Session metadata for receipt enrichment
#
# Resolution Strategy (DETERMINISTIC ONLY):
# 1. Report-provided session_id (explicit in markdown)
# 2. Per-terminal current_session files (deterministic, parallel-safe)
# 3. Environment variables (CLAUDE_SESSION_ID, GEMINI_SESSION_ID, CODEX_SESSION_ID)
# 4. Provider "current" files (~/.codex/sessions/current, ~/.gemini/sessions/current)
# 5. Fallback: "unknown"
#
# Note: Heuristic methods (e.g., "latest transcript") are NOT used to avoid
# incorrect attribution in parallel terminal scenarios.

resolve_session_id() {
    local terminal="${1:-unknown}"
    local report_session_id="${2:-}"

    # Priority 1: From report (explicit - RECOMMENDED)
    if [ -n "$report_session_id" ] && [ "$report_session_id" != "null" ] && [ "$report_session_id" != "unknown" ]; then
        echo "$report_session_id"
        return 0
    fi

    # Priority 2: Per-terminal current_session file (DETERMINISTIC)
    local current_file="${VNX_STATE_DIR:-$HOME/.claude/vnx-system}/current_session_${terminal}"
    if [ -f "$current_file" ]; then
        local session_id=$(cat "$current_file" 2>/dev/null)
        if [ -n "$session_id" ] && [ "$session_id" != "null" ]; then
            echo "$session_id"
            return 0
        fi
    fi

    # Priority 3: Environment variables (provider-specific)
    case "$terminal" in
        T0|T1|T2|T3|T-MANAGER)
            if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
                # Auto-create current_session file for next time
                echo "${CLAUDE_SESSION_ID}" > "$current_file" 2>/dev/null
                echo "${CLAUDE_SESSION_ID}"
                return 0
            fi
            ;;
        GEMINI*)
            if [ -n "${GEMINI_SESSION_ID:-}" ]; then
                echo "${GEMINI_SESSION_ID}" > "$current_file" 2>/dev/null
                echo "${GEMINI_SESSION_ID}"
                return 0
            fi
            ;;
        CODEX*)
            if [ -n "${CODEX_SESSION_ID:-}" ]; then
                echo "${CODEX_SESSION_ID}" > "$current_file" 2>/dev/null
                echo "${CODEX_SESSION_ID}"
                return 0
            fi
            ;;
    esac

    # Priority 4: Provider "current" session files (deterministic)
    # Codex CLI
    if [ -f ~/.codex/sessions/current ]; then
        cat ~/.codex/sessions/current 2>/dev/null || echo "unknown"
        return 0
    fi

    # Gemini CLI
    if [ -f ~/.gemini/sessions/current ]; then
        cat ~/.gemini/sessions/current 2>/dev/null || echo "unknown"
        return 0
    fi

    # Claude Code (if official current file exists)
    if [ -f ~/.claude/sessions/current ]; then
        cat ~/.claude/sessions/current 2>/dev/null || echo "unknown"
        return 0
    fi

    # Fallback: unknown
    echo "unknown"
}

resolve_model_provider() {
    local terminal="$1"
    local state_dir="${VNX_STATE_DIR:-$HOME/.claude/vnx-system}"
    local panes_json="$state_dir/panes.json"

    local model="unknown"
    local provider="unknown"

    # Priority 1: panes.json mapping (if exists)
    if [ -f "$panes_json" ]; then
        model=$(jq -r --arg term "$terminal" '.[$term].model // "unknown"' "$panes_json" 2>/dev/null || echo "unknown")
        provider=$(jq -r --arg term "$terminal" '.[$term].provider // "unknown"' "$panes_json" 2>/dev/null || echo "unknown")
    fi

    # Priority 2: Terminal naming convention heuristic (fallback)
    if [ "$provider" = "unknown" ]; then
        case "$terminal" in
            T0|T1|T2|T3|T-MANAGER)
                provider="claude_code"
                # Default models for Claude terminals (can be overridden in panes.json)
                if [ "$model" = "unknown" ]; then
                    case "$terminal" in
                        T0) model="claude-opus-4.6" ;;
                        T1|T2|T3|T-MANAGER) model="claude-sonnet-4.5" ;;
                    esac
                fi
                ;;
            GEMINI*)
                provider="gemini_cli"
                [ "$model" = "unknown" ] && model="gemini-pro"
                ;;
            CODEX*)
                provider="codex_cli"
                [ "$model" = "unknown" ] && model="gpt-5.2-codex"
                ;;
            *)
                # Check if terminal name contains provider hint
                if [[ "$terminal" == *"gemini"* ]] || [[ "$terminal" == *"GEMINI"* ]]; then
                    provider="gemini_cli"
                    [ "$model" = "unknown" ] && model="gemini-pro"
                elif [[ "$terminal" == *"codex"* ]] || [[ "$terminal" == *"CODEX"* ]]; then
                    provider="codex_cli"
                    [ "$model" = "unknown" ] && model="gpt-5.2-codex"
                else
                    provider="unknown"
                fi
                ;;
        esac
    fi

    # Output as JSON
    printf '{"model":"%s","provider":"%s"}' "$model" "$provider"
}

# Export functions for use in scripts that source this file
export -f resolve_session_id
export -f resolve_model_provider
