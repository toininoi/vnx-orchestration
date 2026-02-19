#!/bin/bash
# Final Option D implementation - Process kill + restart + dispatch injection

set -euo pipefail

PROJECT_ROOT="$PROJECT_ROOT"
TERMS_DIR="$PROJECT_ROOT/.claude/terminals"
VNX_DIR="$PROJECT_ROOT/.claude/vnx-system"

echo "=== OPTION D: FINAL IMPLEMENTATION TEST ==="
echo "Process Kill + Model Change + Dispatch Injection"
echo "Testing on: T1 terminal"
echo ""

# Function to reset Claude session
reset_claude_session() {
    local pane_id="$1"      # %1, %2, %3
    local terminal="$2"      # T1, T2, T3
    local model="$3"         # opus or sonnet
    local dispatch_file="$4" # Path to dispatch content

    echo "Step 1: Finding Claude process in $terminal (pane $pane_id)..."

    # Get TTY for the pane
    local pane_tty=$(tmux list-panes -t vnx:0 -F "#{pane_id} #{pane_tty}" | \
                     grep "$pane_id" | awk '{print $2}')
    echo "  TTY: $pane_tty"

    # Find Claude process
    local claude_pid=$(ps aux | grep claude | grep "$pane_tty" | \
                       grep -v grep | awk '{print $2}' | head -1)

    if [ -n "$claude_pid" ]; then
        echo "  Found Claude PID: $claude_pid"
        echo "  Killing process..."
        kill -TERM "$claude_pid" 2>/dev/null || true
        sleep 1

        # Verify killed
        if ps -p "$claude_pid" > /dev/null 2>&1; then
            echo "  Force killing..."
            kill -9 "$claude_pid" 2>/dev/null || true
        fi
        echo "  ✅ Process terminated"
    else
        echo "  No Claude process running"
    fi

    echo ""
    echo "Step 2: Restarting Claude with model: $model"

    # Navigate to terminal directory and start Claude
    tmux send-keys -t "vnx:0.$pane_id" \
        "cd $TERMS_DIR/$terminal && claude --model $model" C-m

    # Wait for Claude to fully initialize
    echo "  Waiting for Claude initialization..."
    sleep 3  # Increased delay for safety

    echo ""
    echo "Step 3: Injecting dispatch"

    # Read dispatch content
    local dispatch_content=$(cat "$dispatch_file")
    echo "  Dispatch preview: ${dispatch_content:0:50}..."

    # Send dispatch with enter key
    tmux send-keys -t "vnx:0.$pane_id" "$dispatch_content" C-m

    echo "  ✅ Dispatch sent"
    echo ""
}

# Create test dispatch
TEST_DISPATCH="/tmp/test_dispatch.md"
cat > "$TEST_DISPATCH" << 'EOF'
# Test Dispatch for Option D

Please confirm you received this dispatch by:
1. Stating what model you're running (opus or sonnet)
2. Calculating 5+5
3. Saying "Option D works!"
EOF

echo "Created test dispatch:"
cat "$TEST_DISPATCH"
echo ""
echo "---"
echo ""

# Run the test
reset_claude_session "%1" "T1" "sonnet" "$TEST_DISPATCH"

echo "Waiting for response..."
sleep 5

echo "Checking T1 output:"
echo "---"
tmux capture-pane -t vnx:0.%1 -p | tail -20
echo "---"
echo ""

echo "=== SUMMARY ==="
echo "Option D Strategy:"
echo "1. Kill Claude process (preserves pane)"
echo "2. Restart with new model"
echo "3. Wait for initialization (3 seconds)"
echo "4. Send dispatch with enter key"
echo ""
echo "Benefits:"
echo "✅ Stable pane IDs maintained"
echo "✅ Model switching capability"
echo "✅ Clean session reset"
echo "✅ Reliable dispatch delivery"
echo ""
echo "This is our recommended approach for Track 2b!"