#!/bin/bash
# Test mode state cycling and persistence

echo "=== MODE STATE TESTING ==="
echo ""
echo "Current T1 state:"
tmux capture-pane -t vnx:0.%1 -p | tail -3
echo ""

echo "Testing Shift+Tab cycling through all states..."
echo ""

# State 0: Normal (no indicator)
echo "State 0 (Normal): No indicator at bottom"
sleep 2

# State 1: First Shift+Tab
echo "Pressing Shift+Tab once..."
tmux send-keys -t vnx:0.%1 -l $'\e[Z'
sleep 2
echo "State 1:"
tmux capture-pane -t vnx:0.%1 -p | tail -3
echo ""

# State 2: Second Shift+Tab (Plan mode)
echo "Pressing Shift+Tab again..."
tmux send-keys -t vnx:0.%1 -l $'\e[Z'
sleep 2
echo "State 2 (Plan mode):"
tmux capture-pane -t vnx:0.%1 -p | tail -3
echo ""

# State 3: Third Shift+Tab (Accept edits)
echo "Pressing Shift+Tab again..."
tmux send-keys -t vnx:0.%1 -l $'\e[Z'
sleep 2
echo "State 3 (Accept edits):"
tmux capture-pane -t vnx:0.%1 -p | tail -3
echo ""

# State 4: Fourth Shift+Tab (back to normal?)
echo "Pressing Shift+Tab again..."
tmux send-keys -t vnx:0.%1 -l $'\e[Z'
sleep 2
echo "State 4 (Should be back to normal):"
tmux capture-pane -t vnx:0.%1 -p | tail -3
echo ""

echo "=== MODE CYCLING COMPLETE ==="
echo ""
echo "Mode cycle appears to be:"
echo "1. Normal (no indicator)"
echo "2. ??? (first Shift+Tab)"
echo "3. ⏸ plan mode on"
echo "4. ⏵⏵ accept edits on"
echo "5. Back to normal"