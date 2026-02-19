#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/session_resolver.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $msg (expected='$expected' actual='$actual')"
    exit 1
  fi
}

test_env_session_precedence() {
  local saved_claude="${CLAUDE_SESSION_ID:-}"
  local saved_gemini="${GEMINI_SESSION_ID:-}"
  local saved_codex="${CODEX_SESSION_ID:-}"

  export CLAUDE_SESSION_ID="claude-session-1"
  export GEMINI_SESSION_ID="gemini-session-2"
  export CODEX_SESSION_ID="codex-session-3"

  assert_eq "claude-session-1" "$(vnx_session_resolve_id "T1")" "env session id precedence"

  export CLAUDE_SESSION_ID="$saved_claude"
  export GEMINI_SESSION_ID="$saved_gemini"
  export CODEX_SESSION_ID="$saved_codex"
}

test_gemini_current_fallback() {
  local tmp_home
  tmp_home="$(mktemp -d)"
  mkdir -p "$tmp_home/.gemini/sessions"
  printf '%s\n' "gemini-session-abc" > "$tmp_home/.gemini/sessions/current"

  local saved_home="${HOME:-}"
  export HOME="$tmp_home"
  unset CLAUDE_SESSION_ID GEMINI_SESSION_ID CODEX_SESSION_ID || true

  assert_eq "gemini-session-abc" "$(vnx_session_resolve_id "GEMINI-T2")" "gemini current fallback"

  export HOME="$saved_home"
  rm -rf "$tmp_home"
}

test_provider_heuristics() {
  assert_eq "claude_code" "$(vnx_session_resolve_provider "T2" "")" "provider heuristic T* -> claude_code"
  assert_eq "gemini_cli" "$(vnx_session_resolve_provider "GEMINI_T2" "")" "provider heuristic GEMINI -> gemini_cli"
  assert_eq "codex_cli" "$(vnx_session_resolve_provider "CODEX_T3" "")" "provider heuristic CODEX -> codex_cli"
  assert_eq "kimi_cli" "$(vnx_session_resolve_provider "KIMI_T1" "")" "provider heuristic KIMI -> kimi_cli"
  assert_eq "unknown" "$(vnx_session_resolve_provider "worker" "")" "provider heuristic unknown"
}

test_model_from_panes_json_if_jq_available() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "SKIP: jq not installed; panes.json lookup not tested"
    return 0
  fi

  local tmp_state
  tmp_state="$(mktemp -d)"
  cat > "$tmp_state/panes.json" <<'EOF'
{
  "T2": { "provider": "gemini_cli", "model": "gemini-pro" }
}
EOF

  assert_eq "gemini_cli" "$(vnx_session_resolve_provider "T2" "$tmp_state")" "provider from panes.json"
  assert_eq "gemini-pro" "$(vnx_session_resolve_model "T2" "$tmp_state")" "model from panes.json"

  rm -rf "$tmp_state"
}

test_env_session_precedence
test_gemini_current_fallback
test_provider_heuristics
test_model_from_panes_json_if_jq_available

echo "PASS: session resolver helpers"

