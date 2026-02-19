#!/bin/bash
# test_v2_gate_progression.sh - Test Manager Block v2 gate progression

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
VNX_BASE="$VNX_HOME"
SCRIPTS="$VNX_BASE/scripts"

echo "🧪 Manager Block v2 Gate Progression Test"
echo "=========================================="
echo ""

# Test 1: Read v2 metadata from actual dispatch
echo "Test 1: Reading v2 metadata from dispatch 20260114-140227-91d13826-B"
dispatch_id="20260114-140227-91d13826-B"
dispatch_file="$VNX_BASE/dispatches/completed/${dispatch_id}.md"

if [ ! -f "$dispatch_file" ]; then
    echo "❌ Dispatch file not found: $dispatch_file"
    exit 1
fi

on_success=$(grep "^On-Success:" "$dispatch_file" | cut -d: -f2 | xargs)
on_failure=$(grep "^On-Failure:" "$dispatch_file" | cut -d: -f2 | xargs)

echo "  ✅ Found dispatch file"
echo "  📋 On-Success: $on_success"
echo "  📋 On-Failure: $on_failure"
echo ""

# Test 2: Test gate progression with v2 metadata
echo "Test 2: Testing update_progress_state.py with v2 metadata"
echo "  Creating test scenario: Track B completes implementation with success"
echo "  Expected: Should advance to '$on_success' gate (not default 'review')"
echo ""

# Run the python script in test mode
python3 "$SCRIPTS/update_progress_state.py" \
    --track B \
    --advance-gate \
    --status idle \
    --dispatch-id "" \
    --receipt-event "task_complete" \
    --receipt-status "success" \
    --receipt-timestamp "2026-01-14T14:30:00Z" \
    --receipt-dispatch-id "$dispatch_id" \
    --updated-by "test_script" 2>&1 | tee /tmp/v2_test_output.txt

echo ""
echo "Test 2 Output:"
cat /tmp/v2_test_output.txt
echo ""

# Check if v2 metadata was used
if grep -q "Using v2 On-Success gate" /tmp/v2_test_output.txt; then
    echo "  ✅ SUCCESS: v2 metadata was detected and used!"
    used_gate=$(grep "Using v2 On-Success gate" /tmp/v2_test_output.txt | awk '{print $NF}')
    echo "  ✅ Gate used: $used_gate"
    if [ "$used_gate" = "$on_success" ]; then
        echo "  ✅ CORRECT: Gate matches On-Success field from dispatch"
    else
        echo "  ❌ ERROR: Gate '$used_gate' doesn't match On-Success '$on_success'"
    fi
else
    echo "  ❌ FAILURE: v2 metadata was NOT used (fell back to v1 progression)"
    echo "  ⚠️  This means the v2 system is not working correctly"
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
