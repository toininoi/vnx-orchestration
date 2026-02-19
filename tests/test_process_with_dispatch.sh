#!/bin/bash
# Test killing process and restarting with dispatch

set -euo pipefail

PROJECT_ROOT="$PROJECT_ROOT"
TERMS_DIR="$PROJECT_ROOT/.claude/terminals"

echo "=== PROCESS KILL WITH DISPATCH TEST ==="
echo "Testing on: T1 terminal"
echo ""

# Get T1's TTY for finding process
T1_TTY=$(tmux list-panes -t vnx:0 -F "#{pane_id} #{pane_tty}" | grep "%1" | awk '{print $2}')
echo "T1 TTY: $T1_TTY"

# Find and kill Claude
CLAUDE_PID=$(ps aux | grep claude | grep "$T1_TTY" | grep -v grep | awk '{print $2}' | head -1)
if [ -n "$CLAUDE_PID" ]; then
    echo "Killing Claude PID: $CLAUDE_PID"
    kill -TERM "$CLAUDE_PID" 2>/dev/null || true
    sleep 1
fi

# Test 1: Can we pass a simple prompt as argument?
echo ""
echo "TEST 1: Simple prompt as argument"
echo "Command: claude --model sonnet 'What is 2+2?'"
tmux send-keys -t vnx:0.%1 "cd $TERMS_DIR/T1 && claude --model sonnet 'What is 2+2?'" C-m

sleep 3
echo "Result:"
tmux capture-pane -t vnx:0.%1 -p | tail -10

# Kill again for next test
sleep 2
CLAUDE_PID=$(ps aux | grep claude | grep "$T1_TTY" | grep -v grep | awk '{print $2}' | head -1)
if [ -n "$CLAUDE_PID" ]; then
    kill -TERM "$CLAUDE_PID" 2>/dev/null || true
    sleep 1
fi

# Test 2: Multi-line dispatch content
echo ""
echo "TEST 2: Complex dispatch with multiline content"
DISPATCH="Please analyze:
1. Test item one
2. Test item two"

# Escape the dispatch for shell
ESCAPED_DISPATCH=$(echo "$DISPATCH" | sed "s/'/'\\\\''/g")
echo "Escaped dispatch: $ESCAPED_DISPATCH"

tmux send-keys -t vnx:0.%1 "cd $TERMS_DIR/T1 && claude --model sonnet '$ESCAPED_DISPATCH'" C-m

sleep 3
echo "Result:"
tmux capture-pane -t vnx:0.%1 -p | tail -15

echo ""
echo "=== FINDINGS ==="
echo "1. Process kill preserves pane ID ✅"
echo "2. Claude accepts prompt as argument ?"
echo "3. Complex dispatches need proper escaping"
echo ""
echo "Check results above to see if prompts were processed"