#!/bin/bash
# VNX Manual Dispatch Test - Phase 1.2 & 1.3
# Tests Smart Tap extraction and Popup UI functionality

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

PROJECT_ROOT="${PROJECT_ROOT:-$PROJECT_ROOT}"
VNX_DIR="$PROJECT_ROOT/.claude/vnx-system"
STATE_DIR="$VNX_DIR/state"
DISPATCH_DIR="$VNX_DIR/dispatches"
PENDING_DIR="$DISPATCH_DIR/pending"
ACTIVE_DIR="$DISPATCH_DIR/active"
REJECTED_DIR="$DISPATCH_DIR/rejected"
COMPLETED_DIR="$DISPATCH_DIR/completed"
SCRIPTS_DIR="$VNX_DIR/scripts"
SESSION="vnx"

echo "═══════════════════════════════════════════════════════════════"
echo "       VNX Manual Dispatch Test - Phase 1.2 & 1.3"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Function to count files in directory
count_files() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

# Function to simulate manager block in T0
create_test_dispatch() {
    local track="$1"
    local gate="$2"
    local priority="${3:-P1}"
    
    echo -e "${BLUE}Creating test dispatch for Track $track, Gate: $gate${NC}"
    
    # Get T0 pane ID
    T0_PANE=$(jq -r '.t0.pane_id' "$STATE_DIR/panes.json" 2>/dev/null || echo "%72")
    
    # Create manager block content
    local block="[[TARGET:$track]]
Doel: Test $gate task for Track $track validation
Context: [[@docs/test.md]] [[@trackB/TRACK_B_TOTAL_SPRINT_PLAN.MD]]
Gate: $gate
Priority: $priority; Cognition: normal
[[DONE]]"
    
    echo "$block" > /tmp/test_dispatch.txt
    echo -e "${YELLOW}Manager block created:${NC}"
    echo "$block"
    echo ""
    
    # Send to T0 pane
    echo -e "${BLUE}Sending to T0 pane ($T0_PANE)...${NC}"
    tmux send-keys -t "$T0_PANE" C-c Enter 2>/dev/null || true
    sleep 1
    cat /tmp/test_dispatch.txt | tmux load-buffer -
    tmux paste-buffer -t "$T0_PANE"
    tmux send-keys -t "$T0_PANE" Enter
    
    echo -e "${GREEN}✓ Sent to T0${NC}"
}

# Function to check if dispatch was extracted
check_extraction() {
    echo -e "${BLUE}Checking dispatch extraction...${NC}"
    
    local initial_count=$(count_files "$PENDING_DIR")
    echo "Initial pending dispatches: $initial_count"
    
    # Wait for extraction
    local max_wait=10
    local waited=0
    
    while [ "$waited" -lt "$max_wait" ]; do
        sleep 1
        local current_count=$(count_files "$PENDING_DIR")
        if [ "$current_count" -gt "$initial_count" ]; then
            echo -e "${GREEN}✓ Dispatch extracted! New count: $current_count${NC}"
            
            # Show the new dispatch
            local latest=$(ls -t "$PENDING_DIR"/*.md 2>/dev/null | head -1)
            if [ -n "$latest" ]; then
                echo -e "${YELLOW}Latest dispatch: $(basename "$latest")${NC}"
                echo "Content:"
                cat "$latest" | head -10
            fi
            return 0
        fi
        ((waited++))
        echo -n "."
    done
    
    echo ""
    echo -e "${RED}✗ No dispatch extracted after ${max_wait} seconds${NC}"
    return 1
}

# Function to test popup UI
test_popup_ui() {
    echo -e "${BLUE}Testing Popup UI...${NC}"
    
    # Check if popup watcher is running
    if pgrep -f queue_popup_watcher.sh > /dev/null; then
        echo -e "${GREEN}✓ Queue watcher is running${NC}"
    else
        echo -e "${YELLOW}⚠ Starting queue watcher...${NC}"
        nohup "$SCRIPTS_DIR/queue_popup_watcher.sh" > /dev/null 2>&1 &
        sleep 2
    fi
    
    # Check if popup should have opened
    if [ "$(count_files "$PENDING_DIR")" -gt 0 ]; then
        echo -e "${YELLOW}Popup should be visible now${NC}"
        echo ""
        echo "Manual test instructions:"
        echo "1. Check if popup window is visible"
        echo "2. Use arrow keys to navigate dispatches"
        echo "3. Press 'a' to accept a dispatch"
        echo "4. Press 'r' to reject a dispatch"
        echo "5. Press 'e' to edit a dispatch"
        echo "6. Press 'q' to quit popup"
        echo ""
        echo -e "${MAGENTA}Press Enter when you've tested the popup...${NC}"
        read -r
    else
        echo -e "${YELLOW}No pending dispatches for popup test${NC}"
    fi
}

# Main test sequence
echo -e "${BLUE}=== Phase 1.2: Smart Tap Testing ===${NC}"
echo ""

# Check prerequisites
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${RED}✗ VNX session not running!${NC}"
    echo "Run: ./VNX_HYBRID_FINAL.sh first"
    exit 1
fi

# Check if smart tap is running
if pgrep -f smart_tap_v2.sh > /dev/null; then
    echo -e "${GREEN}✓ Smart tap is running${NC}"
else
    echo -e "${YELLOW}⚠ Smart tap not running, starting...${NC}"
    nohup "$SCRIPTS_DIR/smart_tap_v2.sh" > "$STATE_DIR/smart_tap.log" 2>&1 &
    sleep 2
fi

echo ""
echo -e "${BLUE}Test 1: Create and extract planning dispatch${NC}"
echo "────────────────────────────────────────────────"

# Clear pending directory for clean test
echo "Clearing pending directory..."
rm -f "$PENDING_DIR"/*.md 2>/dev/null || true

# Create test dispatch
create_test_dispatch "B" "planning" "P1"

# Check extraction
if check_extraction; then
    echo -e "${GREEN}✓ Test 1 PASSED${NC}"
else
    echo -e "${RED}✗ Test 1 FAILED${NC}"
    echo "Check: $STATE_DIR/t0_conversation.log for captured content"
fi

echo ""
echo -e "${BLUE}=== Phase 1.3: Popup UI Testing ===${NC}"
echo ""

test_popup_ui

echo ""
echo -e "${BLUE}Test 2: Multiple dispatch types${NC}"
echo "────────────────────────────────────────────────"

# Test different gate types
for gate in implementation review testing validation; do
    echo ""
    echo -e "${YELLOW}Testing $gate gate...${NC}"
    create_test_dispatch "B" "$gate" "P2"
    sleep 3
done

echo ""
echo -e "${BLUE}Dispatch Statistics:${NC}"
echo "────────────────────────────────────────────────"
echo "Pending:   $(count_files "$PENDING_DIR")"
echo "Active:    $(count_files "$ACTIVE_DIR")"
echo "Rejected:  $(count_files "$REJECTED_DIR")"
echo "Completed: $(count_files "$COMPLETED_DIR")"

echo ""
echo -e "${BLUE}Test 3: ANSI stripping and format validation${NC}"
echo "────────────────────────────────────────────────"

# Check conversation log for ANSI codes
if [ -f "$STATE_DIR/t0_conversation.log" ]; then
    if grep -q $'\e\[' "$STATE_DIR/t0_conversation.log"; then
        echo -e "${YELLOW}⚠ ANSI codes found in conversation log${NC}"
    else
        echo -e "${GREEN}✓ No ANSI codes in conversation log${NC}"
    fi
    
    # Check for manager blocks
    if grep -q '^\[\[TARGET:' "$STATE_DIR/t0_conversation.log"; then
        echo -e "${GREEN}✓ Manager blocks captured in log${NC}"
    else
        echo -e "${YELLOW}⚠ No manager blocks found in log${NC}"
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}Manual Dispatch Test Complete${NC}"
echo "───────────────────────────────────────────────────────────────"
echo ""
echo "Next steps:"
echo "1. Verify popup UI works correctly"
echo "2. Accept/reject some test dispatches"
echo "3. Check file movement between directories"
echo "4. Run: ./test_receipt_flow.sh for Phase 2"
echo ""
echo -e "${YELLOW}Note: Leave test dispatches in pending/ for next phase${NC}"