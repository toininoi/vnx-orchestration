#!/bin/bash
# Mode Control Validation Test Suite
# Track 2b - Comprehensive testing for mode control integration
# Date: 2026-01-28

set -euo pipefail

PROJECT_ROOT="$PROJECT_ROOT"
VNX_DIR="$PROJECT_ROOT/.claude/vnx-system"
DISPATCH_DIR="$VNX_DIR/dispatches"
TEST_DIR="$VNX_DIR/tests"
LOG_FILE="$TEST_DIR/mode_control_test.log"

# Test configuration
TEST_PANE="%1"  # T1 for testing
DELAY_AFTER_MODE=3  # Seconds to wait after mode activation

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

echo "===== MODE CONTROL VALIDATION TEST SUITE ====="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Source dispatcher functions
source "$VNX_DIR/scripts/dispatcher_v7_compilation.sh" 2>/dev/null || {
    echo "ERROR: Cannot source dispatcher functions"
    exit 1
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

    # Test with no field
    grep -v "ClearContext:" "$test_file" > "/tmp/test_no_clear.md"
    clear=$(extract_clear_context "/tmp/test_no_clear.md")

    if [[ "$clear" == "false" ]]; then
        test_result "Extract ClearContext: default false" "PASS"
    else
        test_result "Extract ClearContext: default false" "FAIL" "(got: $clear)"
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

# Test 6: Mode Configuration Function (dry run)
test_mode_configuration() {
    echo ""
    echo "TEST 6: Mode Configuration Function"

    # Note: This is a dry run test - not actually sending to terminal
    echo "  Testing configure_terminal_mode function existence..."

    if type -t configure_terminal_mode > /dev/null; then
        test_result "configure_terminal_mode exists" "PASS"
    else
        test_result "configure_terminal_mode exists" "FAIL"
    fi

    # Test that function accepts correct parameters
    local test_file="/tmp/test_config.md"
    cat > "$test_file" <<EOF
[[TARGET:A]]
Mode: planning
ClearContext: true
[[DONE]]
EOF

    # Dry run - redirect output to check for errors
    if configure_terminal_mode "%999" "$test_file" 2>&1 | grep -q "MODE_CONTROL"; then
        test_result "configure_terminal_mode runs" "PASS"
    else
        test_result "configure_terminal_mode runs" "FAIL"
    fi

    rm -f "$test_file"
}

# Test 7: Edge Cases
test_edge_cases() {
    echo ""
    echo "TEST 7: Edge Cases"

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
echo "Starting Mode Control Validation Tests..."
echo "========================================="

test_extract_mode
test_extract_clear_context
test_extract_force_normal
test_keyword_detection
test_combined_fields
test_mode_configuration
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
    echo "Mode control integration is ready for use."
    exit 0
else
    echo -e "\n${RED}✗ SOME TESTS FAILED${NC}"
    echo "Please review the log at: $LOG_FILE"
    exit 1
fi