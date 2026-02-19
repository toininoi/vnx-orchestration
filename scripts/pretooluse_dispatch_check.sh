#!/bin/bash
# PreToolUse Hook for Dispatch Validation
# Purpose: Enforce intelligence ACK before dispatch creation
# Token budget: ~50 tokens
# Returns: approve/deny with clear messaging

set -euo pipefail

# Get tool input from environment (Claude Code sets these)
TOOL_NAME="${TOOL_NAME:-unknown}"
FILE_PATH="${TOOL_INPUT_file_path:-}"

# Only check Write tool operations
if [[ "$TOOL_NAME" != "Write" ]]; then
  echo "approve"
  exit 0
fi

# Check if this is a dispatch file
# Match: /dispatches/, /queue/, dispatch*.json, or queue*.json
if [[ ! "$FILE_PATH" =~ (/dispatches/|/queue/|dispatch.*\.json|queue.*\.json) ]]; then
  # Not a dispatch file - approve immediately
  echo "approve"
  exit 0
fi

# This IS a dispatch file - validate intelligence ACK
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
STATE_DIR="$VNX_STATE_DIR"
ACK_SCRIPT="${STATE_DIR}/../scripts/intelligence_ack.sh"
TEMPLATE_VALIDATOR="$VNX_HOME/scripts/validate_template_tokens.py"

# Catch template mutations before dispatch creation
if [[ -f "$TEMPLATE_VALIDATOR" ]]; then
  if ! python3 "$TEMPLATE_VALIDATOR" -q -t report_template -t unified_report_template; then
    echo "deny: Template validation failed for canonical report templates (see $TEMPLATE_VALIDATOR)"
    exit 1
  fi
else
  echo "deny: Template validator missing ($TEMPLATE_VALIDATOR)"
  exit 1
fi

# Run ACK validation script
if [[ -f "$ACK_SCRIPT" ]]; then
  # Script returns "approve" or "deny: <reason>"
  "$ACK_SCRIPT"
else
  # Fallback if script missing
  echo "deny: Intelligence validation script missing (${ACK_SCRIPT})"
  exit 1
fi
