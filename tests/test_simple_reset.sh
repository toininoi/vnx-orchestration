#!/bin/bash
# Simple test for /clear and /model commands

set -euo pipefail

echo "=== SIMPLE RESET TEST FOR T2 ==="
echo ""

# Step 1: Send /clear
echo "Step 1: Sending /clear to T2..."
tmux send-keys -t vnx:0.1 "/clear" C-m

echo "Waiting 3 seconds for /clear to complete..."
sleep 3

# Step 2: Send /model command
echo "Step 2: Sending /model opus to T2..."
tmux send-keys -t vnx:0.1 "/model opus" C-m

echo "Waiting 3 seconds for model switch..."
sleep 3

# Step 3: Send a test dispatch
echo "Step 3: Sending test dispatch..."
tmux send-keys -t vnx:0.1 "What model are you running and what is 7+7?" C-m

echo "Waiting for response..."
sleep 5

# Check output
echo ""
echo "Current T2 output:"
echo "==================="
tmux capture-pane -t vnx:0.1 -p | tail -20
echo "==================="
echo ""
echo "Check above to see if:"
echo "1. /clear worked (should see fresh prompt)"
echo "2. /model opus worked (should confirm Opus model)"
echo "3. Dispatch was processed (should answer 7+7=14)"