#!/bin/bash
# Safe process management approach - kill Claude, not the pane!

set -euo pipefail

PROJECT_ROOT="$PROJECT_ROOT"
TERMS_DIR="$PROJECT_ROOT/.claude/terminals"

echo "=== SAFE PROCESS KILL & RESTART TEST ==="
echo "Testing on: T1 terminal (Track A)"
echo ""

# Get T1's pane PID
T1_PANE_PID=$(tmux list-panes -t vnx:0 -F "#{pane_id} #{pane_pid}" | grep "%1" | awk '{print $2}')
echo "T1 pane PID: $T1_PANE_PID"

# Find Claude process in that pane (child of the pane's shell)
CLAUDE_PID=$(pgrep -P "$T1_PANE_PID" claude || echo "")

if [ -z "$CLAUDE_PID" ]; then
    echo "No Claude process found in T1 pane. Checking alternative method..."
    # Alternative: Find Claude process by checking which TTY it's on
    T1_TTY=$(tmux list-panes -t vnx:0 -F "#{pane_id} #{pane_tty}" | grep "%1" | awk '{print $2}')
    CLAUDE_PID=$(ps aux | grep claude | grep "$T1_TTY" | grep -v grep | awk '{print $2}' | head -1)
fi

if [ -n "$CLAUDE_PID" ]; then
    echo "Found Claude process: PID $CLAUDE_PID"
    echo "Killing Claude process (NOT the pane)..."
    kill -TERM "$CLAUDE_PID" 2>/dev/null || true
    sleep 1

    # Verify process is gone
    if ! ps -p "$CLAUDE_PID" > /dev/null 2>&1; then
        echo "✅ Claude process killed successfully"
    else
        echo "⚠️ Claude process still running, forcing kill..."
        kill -9 "$CLAUDE_PID" 2>/dev/null || true
    fi
else
    echo "No Claude process to kill, pane is empty"
fi

echo ""
echo "Starting new Claude in T1 with dispatch..."

# Method 1: Send command to restart Claude with model flag
echo "Method 1: Using tmux send-keys to restart..."
tmux send-keys -t vnx:0.%1 "cd $TERMS_DIR/T1 && claude --model sonnet" C-m

sleep 2

echo ""
echo "Checking if Claude restarted..."
tmux capture-pane -t vnx:0.%1 -p | tail -5

echo ""
echo "=== TEST COMPLETE ==="
echo ""
echo "Advantages of this approach:"
echo "✅ Pane stays intact (ID %1 preserved)"
echo "✅ No layout disruption"
echo "✅ Dispatcher routing continues to work"
echo "✅ Clean process termination"
echo "✅ Can restart with different model/flags"
echo ""
echo "Next: Test sending initial dispatch after restart"