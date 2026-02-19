#!/bin/bash
# VNX Component Setup Test - Phase 1.1
# Tests all VNX orchestration components are properly installed and configured

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="${PROJECT_ROOT:-$PROJECT_ROOT}"
VNX_DIR="$PROJECT_ROOT/.claude/vnx-system"
TERMINALS_DIR="$PROJECT_ROOT/.claude/terminals"
STATE_DIR="$VNX_DIR/state"
SCRIPTS_DIR="$VNX_DIR/scripts"
DISPATCH_DIR="$VNX_DIR/dispatches"
SESSION="vnx"

echo "═══════════════════════════════════════════════════════════════"
echo "     VNX Orchestration Component Setup Test - Phase 1.1"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_component() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing $test_name... "
    if eval "$test_command" 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo -e "${BLUE}1. Directory Structure Tests${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_component "VNX system directory" "[ -d '$VNX_DIR' ]"
test_component "Orchestration scripts" "[ -d '$SCRIPTS_DIR' ]"
test_component "State directory" "[ -d '$STATE_DIR' ]"
test_component "Dispatch pending" "[ -d '$DISPATCH_DIR/pending' ]"
test_component "Dispatch active" "[ -d '$DISPATCH_DIR/active' ]"
test_component "Dispatch completed" "[ -d '$DISPATCH_DIR/completed' ]"
test_component "Dispatch rejected" "[ -d '$DISPATCH_DIR/rejected' ]"
test_component "Terminal T0" "[ -d '$TERMINALS_DIR/T0' ]"
test_component "Terminal T1" "[ -d '$TERMINALS_DIR/T1' ]"
test_component "Terminal T2" "[ -d '$TERMINALS_DIR/T2' ]"
test_component "Terminal T3" "[ -d '$TERMINALS_DIR/T3' ]"

echo ""
echo -e "${BLUE}2. Core Script Files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_component "Smart tap script" "[ -f '$SCRIPTS_DIR/smart_tap_v2.sh' ]"
test_component "Dispatcher script" "[ -f '$SCRIPTS_DIR/dispatcher_v4_clean.sh' ]"
test_component "Gates controller" "[ -f '$SCRIPTS_DIR/gates_controller.sh' ]"
test_component "Queue popup UI" "[ -f '$SCRIPTS_DIR/queue_ui_popup_fixed.py' ]"
test_component "Queue watcher" "[ -f '$SCRIPTS_DIR/queue_popup_watcher.sh' ]"
test_component "VNX launcher" "[ -f '$PROJECT_ROOT/VNX_HYBRID_FINAL.sh' ]"

echo ""
echo -e "${BLUE}3. State Files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_component "Panes.json" "[ -f '$STATE_DIR/panes.json' ]"
# These may not exist initially but should be created
test_component "State.ndjson (or can create)" "[ -f '$STATE_DIR/state.ndjson' ] || touch '$STATE_DIR/state.ndjson'"
test_component "Receipts.ndjson (or can create)" "[ -f '$STATE_DIR/receipts.ndjson' ] || touch '$STATE_DIR/receipts.ndjson'"
test_component "Dispatch.ndjson (or can create)" "[ -f '$STATE_DIR/dispatch.ndjson' ] || touch '$STATE_DIR/dispatch.ndjson'"
test_component "Conversation log (or can create)" "[ -f '$STATE_DIR/t0_conversation.log' ] || touch '$STATE_DIR/t0_conversation.log'"

echo ""
echo -e "${BLUE}4. Terminal Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_component "T0 CLAUDE.md" "[ -f '$TERMINALS_DIR/T0/CLAUDE.md' ]"
test_component "T1 CLAUDE.md" "[ -f '$TERMINALS_DIR/T1/CLAUDE.md' ]"
test_component "T2 CLAUDE.md" "[ -f '$TERMINALS_DIR/T2/CLAUDE.md' ]"
test_component "T3 CLAUDE.md" "[ -f '$TERMINALS_DIR/T3/CLAUDE.md' ]"

echo ""
echo -e "${BLUE}5. Tmux Session Tests${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if tmux session exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${GREEN}✓ Session '$SESSION' exists${NC}"
    
    # Check pane configuration
    PANE_COUNT=$(tmux list-panes -t "$SESSION" 2>/dev/null | wc -l)
    if [ "$PANE_COUNT" -eq 4 ]; then
        echo -e "${GREEN}✓ Correct number of panes (4)${NC}"
        ((TESTS_PASSED+=2))
    else
        echo -e "${RED}✗ Wrong number of panes (expected 4, got $PANE_COUNT)${NC}"
        ((TESTS_FAILED++))
        ((TESTS_PASSED++))
    fi
    
    # Check pane IDs in panes.json
    if [ -f "$STATE_DIR/panes.json" ]; then
        T0_PANE=$(jq -r '.t0.pane_id' "$STATE_DIR/panes.json" 2>/dev/null)
        if tmux list-panes -F '#{pane_id}' -t "$SESSION" | grep -q "$T0_PANE"; then
            echo -e "${GREEN}✓ T0 pane ID valid in panes.json${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠ T0 pane ID mismatch in panes.json${NC}"
            ((TESTS_FAILED++))
        fi
    fi
else
    echo -e "${YELLOW}⚠ Session '$SESSION' not running${NC}"
    echo "  Run: ./VNX_HYBRID_FINAL.sh to start"
    ((TESTS_FAILED+=3))
fi

echo ""
echo -e "${BLUE}6. Python Dependencies${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_component "Python3 available" "which python3"
test_component "Curses module" "python3 -c 'import curses'"

echo ""
echo -e "${BLUE}7. Process Status${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if orchestration processes are running
if pgrep -f smart_tap_v2.sh > /dev/null; then
    echo -e "${GREEN}✓ Smart tap is running${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ Smart tap not running (start with VNX launcher)${NC}"
    ((TESTS_FAILED++))
fi

if pgrep -f dispatcher_v4_clean.sh > /dev/null; then
    echo -e "${GREEN}✓ Dispatcher is running${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ Dispatcher not running (start with VNX launcher)${NC}"
    ((TESTS_FAILED++))
fi

if pgrep -f queue_popup_watcher.sh > /dev/null; then
    echo -e "${GREEN}✓ Queue watcher is running${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ Queue watcher not running (start with VNX launcher)${NC}"
    ((TESTS_FAILED++))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BLUE}Test Summary${NC}"
echo "───────────────────────────────────────────────────────────────"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All components are properly set up!${NC}"
    echo "  Ready to proceed to Phase 1.2 (Smart Tap Testing)"
    exit 0
else
    echo ""
    echo -e "${YELLOW}⚠ Some components need attention${NC}"
    echo ""
    echo "To fix missing components:"
    echo "1. Run: ./VNX_HYBRID_FINAL.sh    # Start VNX session"
    echo "2. Check file permissions and paths"
    echo "3. Ensure all scripts are executable: chmod +x .claude/vnx-system/*/scripts/*.sh"
    exit 1
fi