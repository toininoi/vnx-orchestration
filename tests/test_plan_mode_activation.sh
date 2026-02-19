#!/bin/bash
# Test Option F: /clear + /model + Plan Mode activation

set -euo pipefail

PROJECT_ROOT="$PROJECT_ROOT"
TERMS_DIR="$PROJECT_ROOT/.claude/terminals"

echo "=== OPTION F: PLAN MODE ACTIVATION TEST ==="
echo "Testing: /clear + /model opusplan + Shift-Tab sequence"
echo "Target: T2 terminal (Track B)"
echo ""

# Function to test plan mode activation
test_plan_mode() {
    local pane_id="%2"  # T2
    local terminal="T2"

    echo "Step 1: Clear context"
    tmux send-keys -t "vnx:0.1" "/clear" C-m  # C-m sends Enter
    sleep 3
    echo "  ✓ /clear sent and executed"

    echo ""
    echo "Step 2: Switch to opusplan model"
    # opusplan is the special model for plan mode (Opus for planning, Sonnet for execution)
    tmux send-keys -t "vnx:0.1" "/model opusplan" C-m  # C-m sends Enter
    sleep 3
    echo "  ✓ Model switch executed"

    echo ""
    echo "Step 3: Activate plan mode with Shift-Tab"
    # Send Shift-Tab twice to enter plan mode
    # In tmux, Shift-Tab is sent as backtab or S-Tab
    tmux send-keys -t "vnx:0.1" S-Tab
    sleep 1
    tmux send-keys -t "vnx:0.1" S-Tab
    sleep 2
    echo "  ✓ Shift-Tab x2 sent (no Enter needed for hotkeys)"

    echo ""
    echo "Step 4: Send test dispatch"
    local dispatch="Analyze the architecture of a web scraping system and create a plan for optimization"
    tmux send-keys -t "vnx:0.1" "$dispatch" C-m
    echo "  ✓ Dispatch sent"
}

echo "Current T2 state:"
tmux capture-pane -t vnx:0.1 -p | tail -5
echo "---"
echo ""

# Run the test
test_plan_mode

echo ""
echo "Waiting for response..."
sleep 5

echo ""
echo "Checking T2 output:"
echo "---"
tmux capture-pane -t vnx:0.1 -p | tail -20
echo "---"
echo ""

echo "=== ANALYSIS ==="
echo "Check above for:"
echo "1. Model switch confirmation (opusplan or opus)"
echo "2. Plan mode indicator (should show 'Planning mode' or similar)"
echo "3. Response style (should be planning-focused, not execution)"
echo ""
echo "Sequence summary:"
echo "  /clear (3s) → /model opusplan (3s) → Shift-Tab x2 (3s) → dispatch"
echo "  Total time: ~9 seconds"