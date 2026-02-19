#!/usr/bin/env bash
#
# Best-effort session/provider/model resolver for multi-provider terminals.
# Intended for bash scripts that need to stamp receipts/reports with session metadata.
#
# Design goals:
# - Model/provider agnostic and non-fatal: unknowns are acceptable.
# - Align with Python resolver behavior in scripts/append_receipt.py and scripts/cost_tracker.py.
#

vnx_session_resolve_id() {
  # Usage: vnx_session_resolve_id [terminal]
  # Returns: session_id or "unknown"
  #
  # Priority:
  # 1) explicit env vars
  # 2) provider current files (~/.codex/sessions/current, ~/.gemini/sessions/current)
  # 3) unknown
  local _terminal="${1:-}"

  local _value=""
  for _value in "${CLAUDE_SESSION_ID:-}" "${GEMINI_SESSION_ID:-}" "${CODEX_SESSION_ID:-}"; do
    if [ -n "${_value:-}" ] && [ "$_value" != "unknown" ] && [ "$_value" != "null" ] && [ "$_value" != "None" ]; then
      printf '%s\n' "$_value"
      return 0
    fi
  done

  local _home="${HOME:-}"
  if [ -n "$_home" ]; then
    local _current
    for _current in "$_home/.codex/sessions/current" "$_home/.gemini/sessions/current"; do
      if [ -f "$_current" ]; then
        _value="$(cat "$_current" 2>/dev/null | head -n 1 | tr -d '[:space:]')"
        if [ -n "${_value:-}" ]; then
          printf '%s\n' "$_value"
          return 0
        fi
      fi
    done
  fi

  : "${_terminal:=}"
  printf '%s\n' "unknown"
}


vnx_session_resolve_provider() {
  # Usage: vnx_session_resolve_provider <terminal> [state_dir]
  # Returns: provider slug (claude_code|codex_cli|gemini_cli|kimi_cli|unknown)
  local terminal="${1:-unknown}"
  local state_dir="${2:-${VNX_STATE_DIR:-}}"

  local provider=""
  if command -v jq >/dev/null 2>&1 && [ -n "${state_dir:-}" ] && [ -f "$state_dir/panes.json" ]; then
    local terminal_lower
    terminal_lower="$(printf '%s' "$terminal" | tr '[:upper:]' '[:lower:]')"
    provider="$(jq -r --arg k "$terminal" --arg kl "$terminal_lower" '.[$k].provider // .[$kl].provider // empty' "$state_dir/panes.json" 2>/dev/null || true)"
    provider="$(printf '%s' "$provider" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  fi

  if [ -n "${provider:-}" ]; then
    printf '%s\n' "$provider"
    return 0
  fi

  local upper
  upper="$(printf '%s' "$terminal" | tr '[:lower:]' '[:upper:]')"
  if [[ "$upper" == T* ]]; then
    printf '%s\n' "claude_code"
  elif [[ "$upper" == *GEMINI* ]]; then
    printf '%s\n' "gemini_cli"
  elif [[ "$upper" == *CODEX* ]]; then
    printf '%s\n' "codex_cli"
  elif [[ "$upper" == *KIMI* ]]; then
    printf '%s\n' "kimi_cli"
  else
    printf '%s\n' "unknown"
  fi
}


vnx_session_resolve_model() {
  # Usage: vnx_session_resolve_model <terminal> [state_dir]
  # Returns: model string or "unknown"
  local terminal="${1:-unknown}"
  local state_dir="${2:-${VNX_STATE_DIR:-}}"

  local model=""
  if command -v jq >/dev/null 2>&1 && [ -n "${state_dir:-}" ] && [ -f "$state_dir/panes.json" ]; then
    local terminal_lower
    terminal_lower="$(printf '%s' "$terminal" | tr '[:upper:]' '[:lower:]')"
    model="$(jq -r --arg k "$terminal" --arg kl "$terminal_lower" '.[$k].model // .[$kl].model // empty' "$state_dir/panes.json" 2>/dev/null || true)"
    model="$(printf '%s' "$model" | tr -d '[:space:]')"
  fi

  if [ -n "${model:-}" ]; then
    printf '%s\n' "$model"
  else
    printf '%s\n' "unknown"
  fi
}
