#!/bin/bash
# Test script for respawn-pane session reset strategy
# Target: T2 terminal (safe to test)

set -euo pipefail

PROJECT_ROOT="$PROJECT_ROOT"
TERMS_DIR="$PROJECT_ROOT/.claude/terminals"
LOG_FILE="/tmp/respawn_test_$(date +%Y%m%d_%H%M%S).log"

echo "=== RESPAWN SESSION TEST ===" | tee "$LOG_FILE"
echo "Testing on: T2 terminal" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Get T2 pane ID from tmux
T2_PANE=$(tmux list-panes -t vnx -F "#{pane_id} #{pane_title}" | grep "T2" | awk '{print $1}' || echo "")

if [ -z "$T2_PANE" ]; then
    echo "ERROR: Could not find T2 pane. Is VNX running?" | tee -a "$LOG_FILE"
    echo "Run: ./VNX_HYBRID_FINAL.sh first" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Found T2 pane: $T2_PANE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Test 1: Basic respawn (kill and restart)
echo "TEST 1: Basic respawn-pane functionality" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

echo "Current process in T2:" | tee -a "$LOG_FILE"
tmux capture-pane -t "$T2_PANE" -p | tail -5 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Executing: tmux respawn-pane -k -t $T2_PANE 'echo Respawn successful!'" | tee -a "$LOG_FILE"
tmux respawn-pane -k -t "$T2_PANE" "echo 'Respawn successful!'; sleep 5"

sleep 2
echo "After respawn:" | tee -a "$LOG_FILE"
tmux capture-pane -t "$T2_PANE" -p | tail -5 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
read -p "Press ENTER to continue to Test 2..."

# Test 2: Respawn with Claude and --model flag
echo "" | tee -a "$LOG_FILE"
echo "TEST 2: Respawn with Claude --model flag" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

CMD="cd $TERMS_DIR/T2 && claude --model sonnet"
echo "Executing: tmux respawn-pane -k -t $T2_PANE '$CMD'" | tee -a "$LOG_FILE"
tmux respawn-pane -k -t "$T2_PANE" "$CMD"

echo "Waiting for Claude to start..." | tee -a "$LOG_FILE"
sleep 5

echo "Claude started with model flag:" | tee -a "$LOG_FILE"
tmux capture-pane -t "$T2_PANE" -p | tail -10 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
read -p "Press ENTER to continue to Test 3..."

# Test 3: Respawn with prompt argument
echo "" | tee -a "$LOG_FILE"
echo "TEST 3: Respawn with Claude and initial prompt" | tee -a "$LOG_FILE"
echo "-----------------------------------------------" | tee -a "$LOG_FILE"

TEST_PROMPT="What is 2+2? Please just answer with the number."
CMD="cd $TERMS_DIR/T2 && claude --model sonnet '$TEST_PROMPT'"
echo "Executing: tmux respawn-pane -k -t $T2_PANE with prompt" | tee -a "$LOG_FILE"
echo "Prompt: $TEST_PROMPT" | tee -a "$LOG_FILE"
tmux respawn-pane -k -t "$T2_PANE" "$CMD"

echo "Waiting for Claude to process prompt..." | tee -a "$LOG_FILE"
sleep 5

echo "Result:" | tee -a "$LOG_FILE"
tmux capture-pane -t "$T2_PANE" -p | tail -15 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
read -p "Press ENTER to continue to Test 4..."

# Test 4: Environment variable inheritance
echo "" | tee -a "$LOG_FILE"
echo "TEST 4: Environment variable inheritance" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

CMD="export TEST_PROFILE=debug-investigation && cd $TERMS_DIR/T2 && echo 'Profile is: \$TEST_PROFILE' && claude --model sonnet"
echo "Testing env inheritance with TEST_PROFILE=debug-investigation" | tee -a "$LOG_FILE"
tmux respawn-pane -k -t "$T2_PANE" "$CMD"

sleep 3
echo "Result:" | tee -a "$LOG_FILE"
tmux capture-pane -t "$T2_PANE" -p | grep -i "profile" | head -5 | tee -a "$LOG_FILE" || echo "No profile output found"

echo "" | tee -a "$LOG_FILE"
read -p "Press ENTER to continue to Test 5..."

# Test 5: Complex dispatch simulation
echo "" | tee -a "$LOG_FILE"
echo "TEST 5: Complex dispatch with multiline content" | tee -a "$LOG_FILE"
echo "-----------------------------------------------" | tee -a "$LOG_FILE"

# Create a test dispatch
DISPATCH_FILE="/tmp/test_dispatch.md"
cat > "$DISPATCH_FILE" << 'EOF'
# Test Dispatch
Please analyze this code:
```python
def hello():
    return "Hello from dispatch!"
```
What does this function do?
EOF

DISPATCH_CONTENT=$(cat "$DISPATCH_FILE" | sed "s/'/'\\\\''/g")
CMD="cd $TERMS_DIR/T2 && claude --model sonnet '$DISPATCH_CONTENT'"

echo "Dispatch content:" | tee -a "$LOG_FILE"
cat "$DISPATCH_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "Executing respawn with dispatch..." | tee -a "$LOG_FILE"
tmux respawn-pane -k -t "$T2_PANE" "$CMD"

echo "Waiting for Claude to process dispatch..." | tee -a "$LOG_FILE"
sleep 7

echo "Result:" | tee -a "$LOG_FILE"
tmux capture-pane -t "$T2_PANE" -p | tail -20 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=== TEST COMPLETE ===" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "SUMMARY:" | tee -a "$LOG_FILE"
echo "1. Basic respawn: Check above for 'Respawn successful!'" | tee -a "$LOG_FILE"
echo "2. Model flag: Check if Claude started with sonnet" | tee -a "$LOG_FILE"
echo "3. Prompt argument: Check if '2+2' prompt was processed" | tee -a "$LOG_FILE"
echo "4. Environment: Check if TEST_PROFILE was inherited" | tee -a "$LOG_FILE"
echo "5. Complex dispatch: Check if code analysis appeared" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Full log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "To restore T2 to normal Claude session:" | tee -a "$LOG_FILE"
echo "tmux respawn-pane -k -t $T2_PANE 'cd $TERMS_DIR/T2 && claude --model sonnet'" | tee -a "$LOG_FILE"