#!/bin/bash
# Corrected mode control testing for T1
# Properly activates modes and keeps them on

set -euo pipefail

echo "=== T1 MODE ACTIVATION TEST (CORRECTED) ==="
echo "Testing mode activation on Terminal 1"
echo ""

# Test 1: Clear context first
echo "Step 1: Clearing context..."
tmux send-keys -t vnx:0.%1 "/clear"
tmux send-keys -t vnx:0.%1 "Enter"
sleep 3
echo "✓ Context cleared"
echo ""

# Test 2: Switch to opus model
echo "Step 2: Switching to opus model..."
tmux send-keys -t vnx:0.%1 "/model opus"
tmux send-keys -t vnx:0.%1 "Enter"
sleep 3
echo "✓ Model switched to opus"
echo ""

# Test 3: Activate thinking mode and KEEP IT ON
echo "Step 3: Activating thinking mode (Tab ONCE)..."
tmux send-keys -t vnx:0.%1 Tab
sleep 2
echo "✓ Thinking mode ACTIVATED"
echo "Should see: ✽ Germinating... indicator"
echo ""

# Test 4: Send a test prompt in thinking mode
echo "Step 4: Testing prompt in thinking mode..."
tmux send-keys -t vnx:0.%1 "What is 2+2? (testing thinking mode)"
tmux send-keys -t vnx:0.%1 "Enter"
echo "Waiting for response..."
sleep 5
echo ""

# Test 5: Turn OFF thinking mode
echo "Step 5: Deactivating thinking mode (Tab again)..."
tmux send-keys -t vnx:0.%1 Tab
sleep 2
echo "✓ Thinking mode DEACTIVATED"
echo ""

# Test 6: Activate plan mode and KEEP IT ON
echo "Step 6: Activating plan mode (Shift+Tab TWICE)..."
tmux send-keys -t vnx:0.%1 -l $'\e[Z'  # First Shift+Tab
sleep 0.5
tmux send-keys -t vnx:0.%1 -l $'\e[Z'  # Second Shift+Tab
sleep 2
echo "✓ Plan mode ACTIVATED"
echo "Should see: ⏸ plan mode on (shift+tab to cycle)"
echo ""

# Test 7: Send a test prompt in plan mode
echo "Step 7: Testing prompt in plan mode..."
tmux send-keys -t vnx:0.%1 "Create a plan for testing mode control (testing plan mode)"
tmux send-keys -t vnx:0.%1 "Enter"
echo "Waiting for response..."
sleep 5
echo ""

# Test 8: Exit plan mode (ONE more Shift+Tab cycles out)
echo "Step 8: Deactivating plan mode (Shift+Tab ONCE more)..."
tmux send-keys -t vnx:0.%1 -l $'\e[Z'  # Third Shift+Tab exits
sleep 2
echo "✓ Plan mode DEACTIVATED"
echo ""

# Test 9: Switch back to sonnet
echo "Step 9: Switching back to sonnet model..."
tmux send-keys -t vnx:0.%1 "/model sonnet"
tmux send-keys -t vnx:0.%1 "Enter"
sleep 3
echo "✓ Model switched back to sonnet"
echo ""

echo "=== TEST COMPLETE ==="
echo ""
echo "Expected behavior:"
echo "1. Context cleared with /clear"
echo "2. Model switched to opus"
echo "3. Thinking mode activated (saw ✽ indicator)"
echo "4. Received thoughtful response to 2+2"
echo "5. Thinking mode deactivated"
echo "6. Plan mode activated (saw ⏸ indicator)"
echo "7. Received planning response"
echo "8. Plan mode deactivated"
echo "9. Model switched back to sonnet"
echo ""
echo "Current T1 status:"
tmux capture-pane -t vnx:0.%1 -p | tail -15