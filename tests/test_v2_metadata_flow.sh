#!/usr/bin/env bash
# Test script to validate v2 metadata extraction and recommendation flow
# Tests the complete pipeline: Report → Receipt → Recommendation → T0 Intelligence

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
VNX_BASE="$VNX_HOME"
SCRIPTS_DIR="$VNX_HOME/scripts"
STATE_DIR="$VNX_STATE_DIR"
REPORTS_DIR="$VNX_REPORTS_DIR"

echo "🧪 Testing V2 Metadata Flow"
echo "======================================="

# Step 1: Create a test report with v2 metadata
TEST_REPORT="$REPORTS_DIR/20260114-120000-T3-TEST-v2-metadata-validation.md"
cat > "$TEST_REPORT" << 'EOF'
# TEST: V2 Metadata Validation Report

**Terminal**: T3
**Track**: C
**Gate**: testing
**Status**: success
**Confidence**: 0.95
**Task ID**: v2-test-001
**Dispatch ID**: 20260114-120000-test-v2-C
**Program**: memory_optimization
**Parent-Dispatch**: 20260114-091045-fc03e1cf-C
**On-Success**: integration
**On-Failure**: investigation
**Reason**: Testing v2 metadata extraction
**Depends-On**: none
**Conflict-Key**: memory_tests
**Allow-Overlap**: false
**Requires-Model**: opus
**Requires-Capability**: analysis

## Summary
Successfully validated v2 metadata extraction and recommendation flow.

## Validation
All tests passed with v2 metadata properly extracted.

## Recommendations
- Proceed to integration gate
- Document v2 metadata handling
EOF

echo "✅ Created test report with full v2 metadata"

# Step 2: Test report parser
echo ""
echo "📋 Testing report parser..."
RECEIPT_JSON=$(python3 "$SCRIPTS_DIR/report_parser.py" "$TEST_REPORT" 2>/dev/null)

# Check if v2 fields are in the receipt
echo "$RECEIPT_JSON" | jq . > /tmp/test_receipt.json
echo "Receipt structure:"
echo "$RECEIPT_JSON" | jq '{
  dispatch_id,
  on_success,
  on_failure,
  program,
  parent_dispatch,
  requires_model
}'

# Verify v2 fields were extracted
if echo "$RECEIPT_JSON" | jq -e '.on_success' > /dev/null; then
    echo "✅ V2 field 'on_success' found in receipt"
else
    echo "❌ V2 field 'on_success' NOT found in receipt"
fi

if echo "$RECEIPT_JSON" | jq -e '.program' > /dev/null; then
    echo "✅ V2 field 'program' found in receipt"
else
    echo "❌ V2 field 'program' NOT found in receipt"
fi

# Step 3: Append to receipts file via canonical helper
echo ""
echo "📝 Adding receipt via append_receipt.py..."
printf '%s' "$RECEIPT_JSON" | python3 "$SCRIPTS_DIR/append_receipt.py"

# Step 4: Run recommendation engine
echo ""
echo "🚀 Running recommendation engine..."
python3 "$SCRIPTS_DIR/generate_t0_recommendations.py" --lookback 5

# Step 5: Check if recommendations were generated
echo ""
echo "📊 Checking recommendations..."
if [[ -f "$STATE_DIR/t0_recommendations.json" ]]; then
    RECOMMENDATIONS=$(jq -r '.recommendations[] | select(.dispatch_id == "20260114-120000-test-v2-C")' "$STATE_DIR/t0_recommendations.json")

    if [[ -n "$RECOMMENDATIONS" ]]; then
        echo "✅ Recommendation generated for v2 dispatch!"
        echo "$RECOMMENDATIONS" | jq '{trigger, action, gate, reason}'

        # Check if it detected on_success
        NEXT_GATE=$(echo "$RECOMMENDATIONS" | jq -r '.gate')
        if [[ "$NEXT_GATE" == "integration" ]]; then
            echo "✅ Correctly detected On-Success: integration"
        else
            echo "⚠️ Expected gate 'integration', got '$NEXT_GATE'"
        fi
    else
        echo "❌ No recommendation found for test dispatch"
    fi
else
    echo "❌ Recommendations file not found"
fi

# Step 6: Test intelligence injection
echo ""
echo "🎯 Testing T0 Intelligence Injection..."
# Clear the hash cache to force update
rm -f "$STATE_DIR/cache/recommendations_last_hash.txt"

# Run the intelligence injection hook
OUTPUT=$(bash "$SCRIPTS_DIR/userpromptsubmit_intelligence_inject.sh" 2>&1)

if echo "$OUTPUT" | grep -q "Recommendations Available"; then
    echo "✅ Recommendations appear in T0 intelligence!"
    echo "$OUTPUT" | grep "Recommendations" -A 3
else
    echo "⚠️ Recommendations not visible in intelligence"
fi

# Cleanup
rm -f "$TEST_REPORT"
echo ""
echo "🧹 Test report cleaned up"
echo ""
echo "📁 Key files to check:"
echo "  • t0_receipts.ndjson (last line should have v2 fields)"
echo "  • t0_recommendations.json (should have recommendation for test dispatch)"
echo "  • /tmp/test_receipt.json (full receipt with v2 metadata)"
