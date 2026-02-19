#!/bin/bash
# Mode Control Validation Test Suite - SAFE VERSION
# Track 2b - Tests only the extraction functions without starting dispatcher
# Date: 2026-01-28

set -euo pipefail

PROJECT_ROOT="$PROJECT_ROOT"
VNX_DIR="$PROJECT_ROOT/.claude/vnx-system"
TEST_DIR="$VNX_DIR/tests"
LOG_FILE="$TEST_DIR/mode_control_test.log"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize log
mkdir -p "$TEST_DIR"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "===== MODE CONTROL VALIDATION TEST SUITE (SAFE) ====="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# COPY the extraction functions from dispatcher (don't source the whole file!)

# Function to extract Mode field from dispatch
extract_mode() {
    local file="$1"
    local mode=$(grep "^Mode:" "$file" 2>/dev/null | sed 's/.*Mode:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    echo "${mode:-none}"
}

# Function to extract ClearContext field
extract_clear_context() {
    local file="$1"
    local clear=$(grep "^ClearContext:" "$file" 2>/dev/null | sed 's/.*ClearContext:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    # DEFAULT TO TRUE - Always clear context unless explicitly set to false
    echo "${clear:-true}"
}

# Function to extract ForceNormalMode field
extract_force_normal_mode() {
    local file="$1"
    local force=$(grep "^ForceNormalMode:" "$file" 2>/dev/null | sed 's/.*ForceNormalMode:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    echo "${force:-false}"
}

# Function to extract Requires-Model field (this one already existed)
extract_requires_model() {
    local file="$1"
    local model=$(grep "^Requires-Model:" "$file" 2>/dev/null | sed 's/.*Requires-Model:\s*//' | sed 's/#.*//' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    echo "${model:-}"
}

# Function to detect mode from keywords (optional, disabled by default)
detect_mode_from_keywords() {
    local file="$1"
    local enable_detection="${MODE_AUTO_DETECTION:-false}"

    if [[ "$enable_detection" != "true" ]]; then
        echo "none"
        return
    fi

    local content=$(cat "$file" | tr '[:upper:]' '[:lower:]')

    if echo "$content" | grep -q "planning gate\|architecture.*design\|system.*planning"; then
        echo "planning"
    elif echo "$content" | grep -q "deep cognition\|complex.*analysis\|root.*cause"; then
        echo "thinking"
    else
        echo "none"
    fi
}

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test result function
test_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ "$result" == "PASS" ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo -e "${GREEN}✓${NC} $test_name: PASS $message"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo -e "${RED}✗${NC} $test_name: FAIL $message"
    fi
}

# Test 1: Extract Mode Field
test_extract_mode() {
    echo ""
    echo "TEST 1: Extract Mode Field"

    # Create test dispatch
    local test_file="/tmp/test_mode_dispatch.md"
    cat > "$test_file" <<EOF
[[TARGET:A]]
Manager Block

Role: developer
Track: A
Terminal: T1
Mode: planning
Gate: architecture
Priority: P1
Cognition: normal

Instruction:
- Test dispatch
[[DONE]]
EOF

    local mode=$(extract_mode "$test_file")

    if [[ "$mode" == "planning" ]]; then
        test_result "Extract Mode: planning" "PASS"
    else
        test_result "Extract Mode: planning" "FAIL" "(got: $mode)"
    fi

    # Test with thinking mode
    sed -i '' 's/Mode: planning/Mode: thinking/' "$test_file" 2>/dev/null || \
    sed -i 's/Mode: planning/Mode: thinking/' "$test_file"
    mode=$(extract_mode "$test_file")

    if [[ "$mode" == "thinking" ]]; then
        test_result "Extract Mode: thinking" "PASS"
    else
        test_result "Extract Mode: thinking" "FAIL" "(got: $mode)"
    fi

    # Test with no mode field
    grep -v "Mode:" "$test_file" > "/tmp/test_no_mode.md"
    mode=$(extract_mode "/tmp/test_no_mode.md")

    if [[ "$mode" == "none" ]]; then
        test_result "Extract Mode: none (default)" "PASS"
    else
        test_result "Extract Mode: none (default)" "FAIL" "(got: $mode)"
    fi

    rm -f "$test_file" "/tmp/test_no_mode.md"
}

# Test 2: Extract ClearContext Field
test_extract_clear_context() {
    echo ""
    echo "TEST 2: Extract ClearContext Field"

    local test_file="/tmp/test_clear_dispatch.md"
    cat > "$test_file" <<EOF
[[TARGET:A]]
Manager Block

Role: developer
ClearContext: true
Gate: implementation

Instruction:
- Test dispatch
[[DONE]]
EOF

    local clear=$(extract_clear_context "$test_file")

    if [[ "$clear" == "true" ]]; then
        test_result "Extract ClearContext: true" "PASS"
    else
        test_result "Extract ClearContext: true" "FAIL" "(got: $clear)"
    fi

    # Test with false
    sed -i '' 's/ClearContext: true/ClearContext: false/' "$test_file" 2>/dev/null || \
    sed -i 's/ClearContext: true/ClearContext: false/' "$test_file"
    clear=$(extract_clear_context "$test_file")

    if [[ "$clear" == "false" ]]; then
        test_result "Extract ClearContext: false" "PASS"
    else
        test_result "Extract ClearContext: false" "FAIL" "(got: $clear)"
    fi

    # Test with no field - should default to TRUE now
    grep -v "ClearContext:" "$test_file" > "/tmp/test_no_clear.md"
    clear=$(extract_clear_context "/tmp/test_no_clear.md")

    if [[ "$clear" == "true" ]]; then
        test_result "Extract ClearContext: default true" "PASS"
    else
        test_result "Extract ClearContext: default true" "FAIL" "(got: $clear)"
    fi

    rm -f "$test_file" "/tmp/test_no_clear.md"
}

# Test 3: Extract ForceNormalMode Field
test_extract_force_normal() {
    echo ""
    echo "TEST 3: Extract ForceNormalMode Field"

    local test_file="/tmp/test_force_dispatch.md"
    cat > "$test_file" <<EOF
[[TARGET:A]]
Manager Block

Role: developer
ForceNormalMode: true
Gate: implementation

Instruction:
- Test dispatch
[[DONE]]
EOF

    local force=$(extract_force_normal_mode "$test_file")

    if [[ "$force" == "true" ]]; then
        test_result "Extract ForceNormalMode: true" "PASS"
    else
        test_result "Extract ForceNormalMode: true" "FAIL" "(got: $force)"
    fi

    # Test default
    grep -v "ForceNormalMode:" "$test_file" > "/tmp/test_no_force.md"
    force=$(extract_force_normal_mode "/tmp/test_no_force.md")

    if [[ "$force" == "false" ]]; then
        test_result "Extract ForceNormalMode: default false" "PASS"
    else
        test_result "Extract ForceNormalMode: default false" "FAIL" "(got: $force)"
    fi

    rm -f "$test_file" "/tmp/test_no_force.md"
}

# Test 4: Keyword Detection (when enabled)
test_keyword_detection() {
    echo ""
    echo "TEST 4: Keyword Detection"

    local test_file="/tmp/test_keywords.md"

    # Test planning keyword
    cat > "$test_file" <<EOF
[[TARGET:A]]
Manager Block

Role: architect
Gate: architecture

Instruction:
- Create planning gate for authentication
- Design system architecture
[[DONE]]
EOF

    # Enable keyword detection
    export MODE_AUTO_DETECTION=true

    local mode=$(detect_mode_from_keywords "$test_file")

    if [[ "$mode" == "planning" ]]; then
        test_result "Keyword Detection: planning gate" "PASS"
    else
        test_result "Keyword Detection: planning gate" "FAIL" "(got: $mode)"
    fi

    # Test thinking keyword
    cat > "$test_file" <<EOF
[[TARGET:A]]
Manager Block

Role: debugging-specialist
Gate: investigation

Instruction:
- Perform deep cognition on performance issue
- Complex analysis required
[[DONE]]
EOF

    mode=$(detect_mode_from_keywords "$test_file")

    if [[ "$mode" == "thinking" ]]; then
        test_result "Keyword Detection: deep cognition" "PASS"
    else
        test_result "Keyword Detection: deep cognition" "FAIL" "(got: $mode)"
    fi

    # Test disabled detection
    export MODE_AUTO_DETECTION=false
    mode=$(detect_mode_from_keywords "$test_file")

    if [[ "$mode" == "none" ]]; then
        test_result "Keyword Detection: disabled" "PASS"
    else
        test_result "Keyword Detection: disabled" "FAIL" "(got: $mode)"
    fi

    rm -f "$test_file"
}

# Test 5: Combined Fields
test_combined_fields() {
    echo ""
    echo "TEST 5: Combined Fields Extraction"

    local test_file="/tmp/test_combined.md"
    cat > "$test_file" <<EOF
[[TARGET:C]]
Manager Block

Role: architect
Track: C
Terminal: T3
Mode: planning
ClearContext: true
ForceNormalMode: true
Requires-Model: opus
Gate: architecture

Instruction:
- Complex architecture task
[[DONE]]
EOF

    local mode=$(extract_mode "$test_file")
    local clear=$(extract_clear_context "$test_file")
    local force=$(extract_force_normal_mode "$test_file")
    local model=$(extract_requires_model "$test_file")

    local all_correct=true

    if [[ "$mode" != "planning" ]]; then
        all_correct=false
        echo "  Mode incorrect: got $mode, expected planning"
    fi

    if [[ "$clear" != "true" ]]; then
        all_correct=false
        echo "  ClearContext incorrect: got $clear, expected true"
    fi

    if [[ "$force" != "true" ]]; then
        all_correct=false
        echo "  ForceNormalMode incorrect: got $force, expected true"
    fi

    if [[ "$model" != "opus" ]]; then
        all_correct=false
        echo "  Requires-Model incorrect: got $model, expected opus"
    fi

    if [[ "$all_correct" == true ]]; then
        test_result "Combined Fields Extraction" "PASS"
    else
        test_result "Combined Fields Extraction" "FAIL"
    fi

    rm -f "$test_file"
}

# Test 6: Edge Cases
test_edge_cases() {
    echo ""
    echo "TEST 6: Edge Cases"

    local test_file="/tmp/test_edge.md"

    # Malformed mode value
    cat > "$test_file" <<EOF
Mode: PLANNING
EOF
    local mode=$(extract_mode "$test_file")
    if [[ "$mode" == "planning" ]]; then
        test_result "Edge: uppercase mode normalized" "PASS"
    else
        test_result "Edge: uppercase mode normalized" "FAIL" "(got: $mode)"
    fi

    # Mode with spaces
    cat > "$test_file" <<EOF
Mode:   planning
EOF
    mode=$(extract_mode "$test_file")
    if [[ "$mode" == "planning" ]]; then
        test_result "Edge: mode with spaces" "PASS"
    else
        test_result "Edge: mode with spaces" "FAIL" "(got: $mode)"
    fi

    # Invalid mode value
    cat > "$test_file" <<EOF
Mode: invalid
EOF
    mode=$(extract_mode "$test_file")
    if [[ "$mode" == "invalid" ]]; then
        test_result "Edge: invalid mode passed through" "PASS"
    else
        test_result "Edge: invalid mode passed through" "FAIL" "(got: $mode)"
    fi

    rm -f "$test_file"
}

# Main test execution
echo "Starting Mode Control Validation Tests (SAFE VERSION)..."
echo "========================================="

test_extract_mode
test_extract_clear_context
test_extract_force_normal
test_keyword_detection
test_combined_fields
test_edge_cases

echo ""
echo "========================================="
echo "TEST SUMMARY"
echo "========================================="
echo -e "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "\n${GREEN}✓ ALL TESTS PASSED!${NC}"
    echo "Mode control extraction functions are working correctly."
    exit 0
else
    echo -e "\n${RED}✗ SOME TESTS FAILED${NC}"
    echo "Please review the log at: $LOG_FILE"
    exit 1
fi