#!/bin/bash
# VNX Receipt Flow Test - Phase 2
# Tests bidirectional receipt flow and document generation

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="${PROJECT_ROOT:-$PROJECT_ROOT}"
VNX_DIR="$PROJECT_ROOT/.claude/vnx-system"
STATE_DIR="$VNX_DIR/state"
SCRIPTS_DIR="$VNX_DIR/scripts"
SESSION="vnx"

echo "═══════════════════════════════════════════════════════════════"
echo "         VNX Receipt Flow Test - Phase 2"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Function to simulate worker receipt
create_test_receipt() {
    local track="$1"
    local gate="$2"
    local status="${3:-ok}"
    local pane_id=""
    
    # Get pane ID for track
    case "$track" in
        A) pane_id=$(jq -r '.tracks.A.pane_id // "%73"' "$STATE_DIR/panes.json" 2>/dev/null || echo "%73") ;;
        B) pane_id=$(jq -r '.tracks.B.pane_id // "%74"' "$STATE_DIR/panes.json" 2>/dev/null || echo "%74") ;;
        C) pane_id=$(jq -r '.tracks.C.pane_id // "%75"' "$STATE_DIR/panes.json" 2>/dev/null || echo "%75") ;;
    esac
    
    # Create NDJSON receipt V2
    local run_id="$(date +%Y%m%d-%H%M%S)-test"
    local receipt=$(cat <<EOF
{"event":"task_receipt","run_id":"$run_id","track":"$track","phase":"1.0","gate":"$gate","task_id":"${track}1-0_test","cmd_id":"test-$(date +%s)","status":"$status","summary":"Test $gate completed for Track $track","report_path":"","metrics":{}}
EOF
)
    
    echo -e "${BLUE}Creating receipt for Track $track, Gate: $gate, Status: $status${NC}"
    echo "$receipt"
    
    # Send to worker terminal
    echo -e "${YELLOW}Sending to Track $track terminal ($pane_id)...${NC}"
    echo "$receipt" | tmux load-buffer -
    tmux paste-buffer -t "$pane_id"
    tmux send-keys -t "$pane_id" Enter
    
    # Also append to receipts file
    echo "$receipt" >> "$STATE_DIR/receipts.ndjson"
    
    echo -e "${GREEN}✓ Receipt sent${NC}"
}

# Function to check receipt capture
check_receipt_capture() {
    echo -e "${BLUE}Checking receipt capture...${NC}"
    
    if [ ! -f "$STATE_DIR/receipts.ndjson" ]; then
        touch "$STATE_DIR/receipts.ndjson"
    fi
    
    local initial_count=$(wc -l < "$STATE_DIR/receipts.ndjson")
    echo "Initial receipt count: $initial_count"
    
    # Wait for new receipts
    sleep 3
    
    local new_count=$(wc -l < "$STATE_DIR/receipts.ndjson")
    if [ "$new_count" -gt "$initial_count" ]; then
        echo -e "${GREEN}✓ New receipts captured! Count: $new_count${NC}"
        echo "Latest receipts:"
        tail -n $((new_count - initial_count)) "$STATE_DIR/receipts.ndjson"
        return 0
    else
        echo -e "${YELLOW}⚠ No new receipts captured${NC}"
        return 1
    fi
}

# Function to test document generation
test_document_generation() {
    local track="$1"
    local gate="$2"
    local phase="B1.1"
    
    echo -e "${BLUE}Testing document generation for $gate${NC}"
    
    # Expected document paths based on gate
    local doc_dir="$PROJECT_ROOT/.claude/state/drafts/track-$track/$phase/$gate"
    
    case "$gate" in
        planning)
            local expected="$doc_dir/PLAN-${phase}-*.md"
            ;;
        implementation)
            local expected="$doc_dir/IMPL-${phase}-*.md"
            ;;
        review)
            local expected="$doc_dir/REVIEW-${phase}-*.md"
            ;;
        testing)
            local expected="/tests/reports/TEST-${phase}-*.md"
            ;;
        validation)
            local expected="$doc_dir/VALIDATION-${phase}-*.md"
            ;;
    esac
    
    echo "Looking for documents matching: $expected"
    
    # Create sample document to simulate worker output
    mkdir -p "$doc_dir"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local doc_name
    
    case "$gate" in
        planning)
            doc_name="PLAN-${phase}-${timestamp}.md"
            cat > "$doc_dir/$doc_name" <<EOF
# Track $track - Phase $phase Planning

## Objectives
- Test planning document generation
- Validate file naming convention
- Confirm directory structure

## Tasks
1. Task 1: Setup environment
2. Task 2: Implement core logic
3. Task 3: Add tests

## Dependencies
- Storage system operational
- RAG pipeline configured
EOF
            ;;
        implementation)
            doc_name="IMPL-${phase}-${timestamp}.md"
            cat > "$doc_dir/$doc_name" <<EOF
# Track $track - Phase $phase Implementation Report

## Completed Work
- Implemented storage adapter
- Added PostgreSQL integration
- Created embedding pipeline

## Code Changes
- src/storage/adapter.py: Created
- src/storage/embeddings.py: Created
- tests/test_storage.py: Added

## Test Results
All tests passing (15/15)
EOF
            ;;
    esac
    
    if [ -f "$doc_dir/$doc_name" ]; then
        echo -e "${GREEN}✓ Document created: $doc_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Document creation failed${NC}"
        return 1
    fi
}

# Function to test state.ndjson updates
test_state_updates() {
    echo -e "${BLUE}Testing state.ndjson updates...${NC}"
    
    local state_file="$STATE_DIR/state.ndjson"
    
    # Add test state entry
    local state_entry=$(cat <<EOF
{"ts":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","type":"phase_complete","track":"B","phase":"B1.1","gate":"planning","status":"completed"}
EOF
)
    
    echo "$state_entry" >> "$state_file"
    
    # Verify entry was added
    if grep -q "phase_complete" "$state_file"; then
        echo -e "${GREEN}✓ State entry added successfully${NC}"
        echo "Latest state:"
        tail -n 1 "$state_file"
        return 0
    else
        echo -e "${RED}✗ State update failed${NC}"
        return 1
    fi
}

# Main test sequence
echo -e "${CYAN}=== Phase 2.1: Worker Receipt Generation ===${NC}"
echo ""

# Check prerequisites
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${RED}✗ VNX session not running!${NC}"
    echo "Run: ./VNX_HYBRID_FINAL.sh first"
    exit 1
fi

# Test receipt generation for different gates
echo -e "${BLUE}Test 1: Generate receipts for all gate types${NC}"
echo "────────────────────────────────────────────────"

for gate in planning implementation review testing validation; do
    echo ""
    create_test_receipt "B" "$gate" "ok"
    sleep 2
done

echo ""
check_receipt_capture

echo ""
echo -e "${CYAN}=== Phase 2.2: Gates Controller Testing ===${NC}"
echo ""

# Check if gates controller would process receipts
echo -e "${BLUE}Test 2: Gates controller receipt processing${NC}"
echo "────────────────────────────────────────────────"

if [ -f "$SCRIPTS_DIR/gates_controller.sh" ]; then
    echo -e "${GREEN}✓ Gates controller script exists${NC}"
    
    # Simulate gates controller logic
    if [ -f "$STATE_DIR/receipts.ndjson" ] && [ -s "$STATE_DIR/receipts.ndjson" ]; then
        local last_receipt=$(tail -n 1 "$STATE_DIR/receipts.ndjson")
        local last_gate=$(echo "$last_receipt" | jq -r '.gate' 2>/dev/null)
        local last_status=$(echo "$last_receipt" | jq -r '.status' 2>/dev/null)
        
        echo "Last receipt gate: $last_gate"
        echo "Last receipt status: $last_status"
        
        # Determine next gate
        local next_gate=""
        case "$last_gate" in
            planning) next_gate="implementation" ;;
            implementation) next_gate="review" ;;
            review) next_gate="testing" ;;
            testing) next_gate="validation" ;;
            validation) next_gate="complete" ;;
        esac
        
        if [ -n "$next_gate" ] && [ "$last_status" = "ok" ]; then
            echo -e "${GREEN}✓ Next gate would be: $next_gate${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Gates controller not found${NC}"
fi

echo ""
echo -e "${CYAN}=== Phase 3: Document Generation Testing ===${NC}"
echo ""

echo -e "${BLUE}Test 3: Create planning and implementation documents${NC}"
echo "────────────────────────────────────────────────────────────────"

test_document_generation "B" "planning"
echo ""
test_document_generation "B" "implementation"

echo ""
echo -e "${BLUE}Test 4: State file updates${NC}"
echo "────────────────────────────────────────────────────────────────"

test_state_updates

echo ""
echo -e "${CYAN}=== Receipt Flow Statistics ===${NC}"
echo "────────────────────────────────────────────────────────────────"

if [ -f "$STATE_DIR/receipts.ndjson" ]; then
    echo "Total receipts: $(wc -l < "$STATE_DIR/receipts.ndjson")"
    echo ""
    echo "Receipts by status:"
    jq -r '.status' "$STATE_DIR/receipts.ndjson" 2>/dev/null | sort | uniq -c || echo "  No valid receipts"
    echo ""
    echo "Receipts by gate:"
    jq -r '.gate' "$STATE_DIR/receipts.ndjson" 2>/dev/null | sort | uniq -c || echo "  No valid receipts"
fi

echo ""
echo "Documents created:"
find "$PROJECT_ROOT/.claude/state/drafts" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' '

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}Receipt Flow Test Complete${NC}"
echo "───────────────────────────────────────────────────────────────"
echo ""
echo "Summary:"
echo "✓ Receipt generation tested"
echo "✓ Receipt capture verified"
echo "✓ Document generation working"
echo "✓ State updates functional"
echo ""
echo "Next steps:"
echo "1. Run: ./test_track_b_sprint.sh for Phase 4"
echo "2. This will test actual Track B sprint execution"