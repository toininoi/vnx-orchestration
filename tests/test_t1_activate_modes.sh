#!/bin/bash
# Simple mode activation test - activates modes and leaves them on
# So you can see the indicators

echo "=== SIMPLE MODE ACTIVATION TEST ==="
echo ""

# Choose which mode to test
echo "Which mode do you want to activate?"
echo "1) Thinking mode (Tab once)"
echo "2) Plan mode (Shift+Tab twice)"
echo "3) Clear and reset to normal"
echo ""
echo "Enter choice (1, 2, or 3):"
read -r choice

case $choice in
    1)
        echo "Activating THINKING mode..."
        tmux send-keys -t vnx:0.%1 Tab
        echo "✓ Thinking mode activated"
        echo "Look for: ✽ Germinating... indicator"
        ;;
    2)
        echo "Activating PLAN mode..."
        tmux send-keys -t vnx:0.%1 -l $'\e[Z'  # First Shift+Tab
        sleep 0.5
        tmux send-keys -t vnx:0.%1 -l $'\e[Z'  # Second Shift+Tab
        echo "✓ Plan mode activated"
        echo "Look for: ⏸ plan mode on (shift+tab to cycle)"
        ;;
    3)
        echo "Clearing context and resetting..."
        tmux send-keys -t vnx:0.%1 "/clear"
        tmux send-keys -t vnx:0.%1 "Enter"
        echo "✓ Context cleared, back to normal mode"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "T1 current status:"
sleep 2
tmux capture-pane -t vnx:0.%1 -p | tail -5