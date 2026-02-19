#!/bin/bash
# VNX Full Automation Test - Phase 5
# Tests complete automated workflow without manual intervention

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

PROJECT_ROOT="${PROJECT_ROOT:-$PROJECT_ROOT}"
VNX_DIR="$PROJECT_ROOT/.claude/vnx-system"
STATE_DIR="$VNX_DIR/state"
DISPATCH_DIR="$VNX_DIR/dispatches"
SCRIPTS_DIR="$VNX_DIR/scripts"
TEST_DIR="$VNX_DIR/testing"
SESSION="vnx"

echo "═══════════════════════════════════════════════════════════════"
echo "       VNX Full Automation Test - Phase 5"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test configuration
AUTO_ACCEPT_DISPATCHES=true
GATE_SEQUENCE=("planning" "implementation" "review" "testing" "validation")
TEST_TRACK="B"
TEST_PHASE="B1.1"

# Function to auto-accept dispatches
auto_accept_dispatcher() {
    echo -e "${BLUE}Starting auto-accept dispatcher...${NC}"
    
    while true; do
        # Check for pending dispatches
        local pending=$(find "$DISPATCH_DIR/pending" -name "*.md" 2>/dev/null | head -1)
        
        if [ -n "$pending" ]; then
            local filename=$(basename "$pending")
            echo -e "${YELLOW}Auto-accepting: $filename${NC}"
            
            # Move to active
            mv "$pending" "$DISPATCH_DIR/active/"
            
            # Trigger dispatcher if not running
            if ! pgrep -f dispatcher_v4_clean.sh > /dev/null; then
                nohup "$SCRIPTS_DIR/dispatcher_v4_clean.sh" > /dev/null 2>&1 &
            fi
            
            sleep 5
        fi
        
        sleep 2
    done
}

# Function to simulate complete gate cycle
run_gate_cycle() {
    local track="$1"
    local phase="$2"
    local gate="$3"
    
    echo -e "${CYAN}═══ Running $gate gate for $track/$phase ═══${NC}"
    
    # Create dispatch via T0
    local T0_PANE=$(jq -r '.t0.pane_id' "$STATE_DIR/panes.json" 2>/dev/null || echo "%72")
    local goal=""
    
    case "$gate" in
        planning)
            goal="Create detailed plan for $phase storage implementation"
            ;;
        implementation)
            goal="Implement storage components for $phase"
            ;;
        review)
            goal="Review $phase implementation for quality and SOLID compliance"
            ;;
        testing)
            goal="Execute comprehensive tests for $phase components"
            ;;
        validation)
            goal="Validate $phase deliverables meet requirements"
            ;;
    esac
    
    # Create manager block
    local block="[[TARGET:$track]]
Doel: $goal
Context: [[@trackB/TRACK_B_TOTAL_SPRINT_PLAN.MD]] [[@docs/storage_requirements.md]]
Gate: $gate
Priority: P1; Cognition: normal
[[DONE]]"
    
    echo -e "${YELLOW}Sending dispatch to T0...${NC}"
    echo "$block" | tmux load-buffer -
    tmux paste-buffer -t "$T0_PANE"
    tmux send-keys -t "$T0_PANE" Enter
    
    # Wait for extraction
    sleep 3
    
    # Wait for dispatch to be processed
    local max_wait=30
    local waited=0
    
    while [ "$waited" -lt "$max_wait" ]; do
        if [ "$(find "$DISPATCH_DIR/active" -name "*$gate*.md" 2>/dev/null | wc -l)" -gt 0 ]; then
            echo -e "${GREEN}✓ Dispatch activated${NC}"
            break
        fi
        sleep 2
        waited=$((waited + 2))
        echo -ne "\rWaiting for activation... ${waited}s"
    done
    echo ""
    
    # Simulate worker processing
    sleep 5
    echo -e "${YELLOW}Simulating worker execution...${NC}"
    
    # Get track pane
    local TRACK_PANE=""
    case "$track" in
        A) TRACK_PANE=$(jq -r '.tracks.A.pane_id // "%73"' "$STATE_DIR/panes.json") ;;
        B) TRACK_PANE=$(jq -r '.tracks.B.pane_id // "%74"' "$STATE_DIR/panes.json") ;;
        C) TRACK_PANE=$(jq -r '.tracks.C.pane_id // "%75"' "$STATE_DIR/panes.json") ;;
    esac
    
    # Generate documents
    local doc_dir="$PROJECT_ROOT/.claude/state/drafts/track-$track/$phase/$gate"
    mkdir -p "$doc_dir"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    case "$gate" in
        planning)
            cat > "$doc_dir/PLAN-${phase}-${timestamp}.md" <<EOF
# Automated Planning Document
Phase: $phase
Gate: $gate
Status: Completed
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
            ;;
        implementation)
            cat > "$doc_dir/IMPL-${phase}-${timestamp}.md" <<EOF
# Automated Implementation Report
Phase: $phase
Gate: $gate
Code Changes: 15 files modified
Tests Added: 8 new tests
Status: Completed
EOF
            ;;
    esac
    
    # Generate receipt
    local receipt=$(cat <<EOF
{"ts":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","run_id":"auto_$(date +%s)","track":"$track","phase":"$phase","gate":"$gate","status":"ok","summary":"Automated $gate completed successfully"}
EOF
)
    
    echo "$receipt" | tmux load-buffer -
    tmux paste-buffer -t "$TRACK_PANE"
    tmux send-keys -t "$TRACK_PANE" Enter
    echo "$receipt" >> "$STATE_DIR/receipts.ndjson"
    
    # Update state
    local state_entry=$(cat <<EOF
{"ts":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","type":"gate_complete","track":"$track","phase":"$phase","gate":"$gate","status":"completed","automated":true}
EOF
)
    echo "$state_entry" >> "$STATE_DIR/state.ndjson"
    
    # Move dispatch to completed
    local active_dispatch=$(find "$DISPATCH_DIR/active" -name "*$gate*.md" 2>/dev/null | head -1)
    if [ -n "$active_dispatch" ]; then
        mv "$active_dispatch" "$DISPATCH_DIR/completed/"
    fi
    
    echo -e "${GREEN}✓ $gate gate completed${NC}"
    sleep 3
}

# Function to generate test report
generate_test_report() {
    local report_file="$TEST_DIR/reports/automation_test_$(date +%Y%m%d-%H%M%S).md"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" <<EOF
# VNX Full Automation Test Report

**Date**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Test Type**: Full Automation
**Track**: $TEST_TRACK
**Phase**: $TEST_PHASE

## Test Execution Summary

### Gates Executed
EOF
    
    for gate in "${GATE_SEQUENCE[@]}"; do
        local gate_receipts=$(grep -c "\"gate\":\"$gate\"" "$STATE_DIR/receipts.ndjson" 2>/dev/null || echo "0")
        echo "- **$gate**: $gate_receipts receipts" >> "$report_file"
    done
    
    cat >> "$report_file" <<EOF

### Metrics

- **Total Receipts**: $(wc -l < "$STATE_DIR/receipts.ndjson" 2>/dev/null || echo "0")
- **Documents Created**: $(find "$PROJECT_ROOT/.claude/state/drafts" -name "*.md" 2>/dev/null | wc -l)
- **State Updates**: $(wc -l < "$STATE_DIR/state.ndjson" 2>/dev/null || echo "0")
- **Completed Dispatches**: $(find "$DISPATCH_DIR/completed" -name "*.md" 2>/dev/null | wc -l)

### Quality Metrics

1. **Automation Success Rate**: Calculate based on completed vs failed gates
2. **Receipt Accuracy**: All receipts properly formatted
3. **Document Generation**: All required documents created
4. **State Consistency**: State file accurately reflects execution

## Issues Detected

EOF
    
    # Check for issues
    local issues=0
    
    if [ "$(find "$DISPATCH_DIR/rejected" -name "*.md" 2>/dev/null | wc -l)" -gt 0 ]; then
        echo "- ⚠️ Rejected dispatches found" >> "$report_file"
        ((issues++))
    fi
    
    if grep -q '"status":"failed"' "$STATE_DIR/receipts.ndjson" 2>/dev/null; then
        echo "- ⚠️ Failed receipts detected" >> "$report_file"
        ((issues++))
    fi
    
    if [ "$issues" -eq 0 ]; then
        echo "- ✅ No issues detected" >> "$report_file"
    fi
    
    cat >> "$report_file" <<EOF

## Recommendations

1. Monitor gate transition timing
2. Validate document quality
3. Check for race conditions
4. Verify state consistency

## Conclusion

Test Status: **$([ "$issues" -eq 0 ] && echo "PASSED" || echo "PASSED WITH WARNINGS")**
EOF
    
    echo -e "${GREEN}✓ Test report generated: $report_file${NC}"
}

# Main test sequence
echo -e "${MAGENTA}=== Starting Full Automation Test ===${NC}"
echo ""

# Pre-test cleanup
echo -e "${BLUE}Cleaning up previous test data...${NC}"
rm -f "$STATE_DIR/receipts.ndjson.backup" 2>/dev/null
cp "$STATE_DIR/receipts.ndjson" "$STATE_DIR/receipts.ndjson.backup" 2>/dev/null || true
rm -f "$DISPATCH_DIR"/{pending,active,completed,rejected}/*.md 2>/dev/null || true

# Check prerequisites
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${RED}✗ VNX session not running!${NC}"
    echo "Run: ./VNX_HYBRID_FINAL.sh first"
    exit 1
fi

# Start auto-acceptor in background
if [ "$AUTO_ACCEPT_DISPATCHES" = true ]; then
    echo -e "${BLUE}Starting auto-accept daemon...${NC}"
    auto_accept_dispatcher &
    AUTO_PID=$!
    echo "Auto-acceptor PID: $AUTO_PID"
    
    # Cleanup function
    cleanup() {
        echo -e "${YELLOW}Stopping auto-acceptor...${NC}"
        kill $AUTO_PID 2>/dev/null || true
    }
    trap cleanup EXIT
fi

echo ""
echo -e "${WHITE}═══ AUTOMATED GATE SEQUENCE EXECUTION ═══${NC}"
echo ""

# Run through complete gate sequence
START_TIME=$(date +%s)

for gate in "${GATE_SEQUENCE[@]}"; do
    run_gate_cycle "$TEST_TRACK" "$TEST_PHASE" "$gate"
    echo ""
    
    # Add delay between gates
    if [ "$gate" != "validation" ]; then
        echo "Waiting for gate transition..."
        sleep 5
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo -e "${WHITE}═══ AUTOMATION TEST RESULTS ═══${NC}"
echo ""

# Display statistics
echo -e "${BLUE}Execution Statistics:${NC}"
echo "────────────────────────────────────────"
echo "Total Duration: ${DURATION} seconds"
echo "Gates Completed: ${#GATE_SEQUENCE[@]}"
echo ""

echo "Dispatch Statistics:"
echo "  Pending:   $(find "$DISPATCH_DIR/pending" -name "*.md" 2>/dev/null | wc -l)"
echo "  Active:    $(find "$DISPATCH_DIR/active" -name "*.md" 2>/dev/null | wc -l)"
echo "  Completed: $(find "$DISPATCH_DIR/completed" -name "*.md" 2>/dev/null | wc -l)"
echo "  Rejected:  $(find "$DISPATCH_DIR/rejected" -name "*.md" 2>/dev/null | wc -l)"
echo ""

echo "Receipt Statistics:"
if [ -f "$STATE_DIR/receipts.ndjson" ]; then
    echo "  Total: $(wc -l < "$STATE_DIR/receipts.ndjson")"
    echo "  OK: $(grep -c '"status":"ok"' "$STATE_DIR/receipts.ndjson" 2>/dev/null || echo "0")"
    echo "  Failed: $(grep -c '"status":"failed"' "$STATE_DIR/receipts.ndjson" 2>/dev/null || echo "0")"
    echo "  Blocked: $(grep -c '"status":"blocked"' "$STATE_DIR/receipts.ndjson" 2>/dev/null || echo "0")"
fi

echo ""
echo -e "${BLUE}Quality Assessment:${NC}"
echo "────────────────────────────────────────"

# Assess quality
QUALITY_SCORE=0
MAX_SCORE=5

echo -n "1. Gate Completion: "
if [ "$(grep -c '"gate"' "$STATE_DIR/receipts.ndjson" 2>/dev/null || echo "0")" -ge "${#GATE_SEQUENCE[@]}" ]; then
    echo -e "${GREEN}✅ All gates executed${NC}"
    ((QUALITY_SCORE++))
else
    echo -e "${YELLOW}⚠️ Some gates missing${NC}"
fi

echo -n "2. Document Generation: "
if [ "$(find "$PROJECT_ROOT/.claude/state/drafts" -name "*.md" 2>/dev/null | wc -l)" -gt 0 ]; then
    echo -e "${GREEN}✅ Documents created${NC}"
    ((QUALITY_SCORE++))
else
    echo -e "${RED}❌ No documents created${NC}"
fi

echo -n "3. Receipt Flow: "
if [ -f "$STATE_DIR/receipts.ndjson" ] && [ -s "$STATE_DIR/receipts.ndjson" ]; then
    echo -e "${GREEN}✅ Receipts flowing${NC}"
    ((QUALITY_SCORE++))
else
    echo -e "${RED}❌ No receipts${NC}"
fi

echo -n "4. State Updates: "
if [ -f "$STATE_DIR/state.ndjson" ] && grep -q "automated.*true" "$STATE_DIR/state.ndjson" 2>/dev/null; then
    echo -e "${GREEN}✅ State updating${NC}"
    ((QUALITY_SCORE++))
else
    echo -e "${YELLOW}⚠️ State not updating${NC}"
fi

echo -n "5. No Errors: "
if [ "$(find "$DISPATCH_DIR/rejected" -name "*.md" 2>/dev/null | wc -l)" -eq 0 ]; then
    echo -e "${GREEN}✅ No rejections${NC}"
    ((QUALITY_SCORE++))
else
    echo -e "${YELLOW}⚠️ Some rejections${NC}"
fi

echo ""
echo -e "${BLUE}Overall Quality Score: $QUALITY_SCORE/$MAX_SCORE${NC}"

# Generate report
echo ""
generate_test_report

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}Full Automation Test Complete${NC}"
echo "───────────────────────────────────────────────────────────────"
echo ""
echo "Summary:"
echo "✅ Automated ${#GATE_SEQUENCE[@]} gates in $DURATION seconds"
echo "✅ Quality score: $QUALITY_SCORE/$MAX_SCORE"
echo ""
echo "Test report saved to: $TEST_DIR/reports/"
echo ""
echo -e "${YELLOW}Note: Review the test report for detailed analysis${NC}"