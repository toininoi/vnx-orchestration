#!/bin/bash
# Monitor T1 terminal for mode changes during testing
# Track 2b Context Intelligence Testing

echo "=== T1 MODE CONTROL TEST MONITOR ==="
echo "Monitoring Terminal 1 for mode indicators..."
echo ""
echo "Looking for:"
echo "  - ⏸ plan mode on (shift+tab to cycle)"
echo "  - ✽ Germinating... (thinking mode)"
echo "  - Model switches (/model opus or /model sonnet)"
echo "  - Context clears (/clear command)"
echo ""

# Function to check T1 state
check_t1() {
    local timestamp=$(date +"%H:%M:%S")
    echo "[$timestamp] T1 Status Check:"
    echo "---"
    # Capture last 15 lines to look for mode indicators
    tmux capture-pane -t "vnx:0.%1" -p | tail -15
    echo "---"
    echo ""
}

# Initial check
echo "Initial T1 state:"
check_t1

# Monitor for 2 minutes with checks every 5 seconds
echo "Starting continuous monitoring (2 minutes)..."
for i in {1..24}; do
    sleep 5
    echo "Check #$i"
    check_t1
done

echo "=== MONITORING COMPLETE ==="
echo "Review above for any mode changes or indicators"