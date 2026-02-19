#!/bin/bash
# Manual mode control testing for T1
# Tests each mode control command independently

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/vnx_paths.sh
source "$SCRIPT_DIR/../scripts/lib/vnx_paths.sh"
# shellcheck source=../scripts/pane_config.sh
source "$SCRIPT_DIR/../scripts/pane_config.sh"

PROVIDER="${1:-${VNX_T1_PROVIDER:-claude_code}}"
PROVIDER="$(echo "$PROVIDER" | tr '[:upper:]' '[:lower:]')"

T1_PANE_ID="$(get_pane_id "T1" "$VNX_STATE_DIR/panes.json" 2>/dev/null || echo "%1")"
TMUX_TARGET="vnx:0.${T1_PANE_ID}"

clear_cmd="/clear"
case "$PROVIDER" in
  codex_cli|codex) clear_cmd="/new" ;;
esac

echo "=== T1 MANUAL MODE CONTROL TEST ==="
echo "Testing mode commands on Terminal 1"
echo "Provider: $PROVIDER"
echo "Target: $TMUX_TARGET"
echo ""

# Test 1: /clear command
echo "Test 1: Sending $clear_cmd to T1..."
tmux send-keys -t "$TMUX_TARGET" "$clear_cmd"
tmux send-keys -t "$TMUX_TARGET" "Enter"  # Use "Enter" with quotes as discovered
echo "Waiting 3 seconds..."
sleep 3
echo "✓ Context reset sent"
echo ""

# Test 2: /model command
if [[ "$PROVIDER" == "claude_code" ]]; then
  echo "Test 2: Switching to opus model..."
  tmux send-keys -t "$TMUX_TARGET" "/model opus"
  tmux send-keys -t "$TMUX_TARGET" "Enter"
  echo "Waiting 3 seconds..."
  sleep 3
  echo "✓ /model opus sent"
else
  echo "Test 2: Switching Codex model (optional)..."
  if [[ -n "${VNX_T1_MODEL:-}" ]]; then
    tmux send-keys -t "$TMUX_TARGET" "/model ${VNX_T1_MODEL}"
    tmux send-keys -t "$TMUX_TARGET" "Enter"
    echo "Waiting 3 seconds..."
    sleep 3
    echo "✓ /model ${VNX_T1_MODEL} sent"
  else
    echo "⚠️  VNX_T1_MODEL not set; skipping model switch"
  fi
fi
echo ""

# Test 3: Thinking mode (single Tab)
if [[ "$PROVIDER" == "claude_code" ]]; then
  echo "Test 3: Activating thinking mode with Tab..."
  tmux send-keys -t "$TMUX_TARGET" Tab
  echo "Waiting 2 seconds..."
  sleep 2
  echo "✓ Thinking mode activation sent"
  echo "Look for: ✽ Germinating... indicator"
  echo ""

  # Test 4: Exit thinking mode (Tab again)
  echo "Test 4: Deactivating thinking mode with Tab..."
  tmux send-keys -t "$TMUX_TARGET" Tab
  echo "Waiting 2 seconds..."
  sleep 2
  echo "✓ Thinking mode deactivation sent"
  echo ""

  # Test 5: Plan mode (Shift+Tab twice)
  echo "Test 5: Activating plan mode with Shift+Tab x2..."
  tmux send-keys -t "$TMUX_TARGET" -l $'\e[Z'  # First Shift+Tab
  sleep 0.5
  tmux send-keys -t "$TMUX_TARGET" -l $'\e[Z'  # Second Shift+Tab
  echo "Waiting 2 seconds..."
  sleep 2
  echo "✓ Plan mode activation sent"
  echo "Look for: ⏸ plan mode on indicator"
  echo ""

  # Test 6: Exit plan mode (Shift+Tab once more)
  echo "Test 6: Deactivating plan mode with Shift+Tab..."
  tmux send-keys -t "$TMUX_TARGET" -l $'\e[Z'  # Third Shift+Tab exits
  echo "Waiting 2 seconds..."
  sleep 2
  echo "✓ Plan mode deactivation sent"
  echo ""
else
  echo "Skipping thinking/planning mode tests (provider '$PROVIDER' does not support Tab/Shift+Tab toggles)."
  echo ""
fi

# Test 7: Switch back to sonnet
if [[ "$PROVIDER" == "claude_code" ]]; then
  echo "Test 7: Switching back to sonnet model..."
  tmux send-keys -t "$TMUX_TARGET" "/model sonnet"
  tmux send-keys -t "$TMUX_TARGET" "Enter"
  echo "Waiting 3 seconds..."
  sleep 3
  echo "✓ /model sonnet sent"
fi
echo ""

echo "=== TEST COMPLETE ==="
echo "Check T1 output above for:"
echo "1. Context reset after $clear_cmd"
echo "2. Model switch confirmations"
echo "3. Mode indicators (✽ for thinking, ⏸ for planning) (Claude only)"
echo ""
echo "Current T1 status:"
tmux capture-pane -t "$TMUX_TARGET" -p | tail -10
