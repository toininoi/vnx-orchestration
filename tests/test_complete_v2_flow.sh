#!/usr/bin/env bash
# Complete test of v2 metadata flow with dispatch creation
# Tests: Dispatch → Report → Receipt → Recommendation → T0 Intelligence

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
VNX_BASE="$VNX_HOME"
SCRIPTS_DIR="$VNX_HOME/scripts"
STATE_DIR="$VNX_STATE_DIR"
DISPATCHES_DIR="$VNX_DISPATCH_DIR"
REPORTS_DIR="$VNX_REPORTS_DIR"

echo "🧪 Testing Complete V2 Flow"
echo "======================================="

# Generate unique IDs
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
DISPATCH_ID="${TIMESTAMP}-test-v2-C"

# Step 1: Create a v2 dispatch in completed folder
DISPATCH_FILE="$DISPATCHES_DIR/completed/${DISPATCH_ID}.md"
cat > "$DISPATCH_FILE" << 'EOF'
# Manager Block

**Role**: developer
**Track**: C
**Terminal**: T3
**Gate**: testing
**Priority**: P1
**Program**: test_suite
**Dispatch-ID**: ${DISPATCH_ID}
**Parent-Dispatch**: none
**On-Success**: integration
**On-Failure**: investigation
**Reason**: Testing v2 metadata flow
**Depends-On**: none
**Conflict-Key**: test_v2
**Allow-Overlap**: false
**Requires-Model**: opus
**Requires-Capability**: testing

**Instruction**:
Test the v2 metadata extraction and recommendation flow.
Verify that all v2 fields are properly parsed and recommendations are generated.
EOF

# Replace the dispatch ID in the file
sed -i '' "s/\${DISPATCH_ID}/${DISPATCH_ID}/g" "$DISPATCH_FILE"

echo "✅ Created v2 dispatch: $DISPATCH_ID"

# Step 2: Create a corresponding completion report
TEST_REPORT="$REPORTS_DIR/${TIMESTAMP}-T3-TEST-v2-metadata-complete.md"
cat > "$TEST_REPORT" << EOF
# TEST: V2 Metadata Complete Flow

**Terminal**: T3
**Track**: C
**Gate**: testing
**Status**: success
**Confidence**: 0.95
**Task ID**: test-v2-flow
**Dispatch ID**: ${DISPATCH_ID}

## Summary
Successfully completed v2 metadata test with all fields validated.

## Validation
- Receipt parser: ✅ Extracts v2 fields
- Recommendation engine: ✅ Processes v2 metadata
- Intelligence injection: ✅ Shows recommendations

## Metrics
Tests passed: 3
Coverage: 100%

## Recommendations
- Proceed to integration gate as specified in On-Success
- Document v2 metadata handling for other terminals
EOF

echo "✅ Created completion report for dispatch"

# Step 3: Parse the report and add to receipts
echo ""
echo "📋 Parsing report..."
RECEIPT_JSON=$(python3 "$SCRIPTS_DIR/report_parser.py" "$TEST_REPORT" 2>/dev/null)

# Display key v2 fields
echo "Extracted v2 metadata from report:"
echo "$RECEIPT_JSON" | jq '{
  dispatch_id,
  status,
  gate,
  event_type
}'

# Append to receipts via canonical helper
printf '%s' "$RECEIPT_JSON" | python3 "$SCRIPTS_DIR/append_receipt.py"
echo "✅ Added receipt via append_receipt.py"

# Step 4: Run recommendation engine
echo ""
echo "🚀 Running recommendation engine..."
python3 "$SCRIPTS_DIR/generate_t0_recommendations.py" --lookback 10

# Step 5: Check recommendations
echo ""
echo "📊 Checking generated recommendations..."
if [[ -f "$STATE_DIR/t0_recommendations.json" ]]; then
    TOTAL=$(jq -r '.total_recommendations' "$STATE_DIR/t0_recommendations.json")

    if [[ "$TOTAL" -gt 0 ]]; then
        echo "✅ Generated $TOTAL recommendations!"

        # Check for our specific dispatch
        RECOMMENDATION=$(jq -r ".recommendations[] | select(.dispatch_id == \"$DISPATCH_ID\")" "$STATE_DIR/t0_recommendations.json")

        if [[ -n "$RECOMMENDATION" ]]; then
            echo "✅ Found recommendation for our test dispatch:"
            echo "$RECOMMENDATION" | jq '{trigger, action, gate, reason}'

            # Verify it detected On-Success
            NEXT_GATE=$(echo "$RECOMMENDATION" | jq -r '.gate')
            if [[ "$NEXT_GATE" == "integration" ]]; then
                echo "✅ SUCCESS: Correctly detected On-Success → integration"
            else
                echo "❌ FAIL: Expected 'integration', got '$NEXT_GATE'"
            fi
        else
            echo "⚠️ No recommendation found for dispatch $DISPATCH_ID"
        fi
    else
        echo "❌ No recommendations generated"
    fi
else
    echo "❌ Recommendations file not created"
fi

# Step 6: Test T0 intelligence injection
echo ""
echo "🎯 Testing T0 Intelligence Injection..."
rm -f "$STATE_DIR/cache/recommendations_last_hash.txt"
OUTPUT=$(bash "$SCRIPTS_DIR/userpromptsubmit_intelligence_inject.sh" 2>&1)

if echo "$OUTPUT" | grep -q "Recommendations Available"; then
    echo "✅ Recommendations visible in T0 intelligence!"
    echo "$OUTPUT" | grep -A 5 "Recommendations"
else
    echo "❌ Recommendations not in intelligence output"
fi

# Step 7: Verify complete chain
echo ""
echo "📊 Complete Chain Verification:"
echo -n "1. Dispatch created: "
[[ -f "$DISPATCH_FILE" ]] && echo "✅" || echo "❌"

echo -n "2. Report created: "
[[ -f "$TEST_REPORT" ]] && echo "✅" || echo "❌"

echo -n "3. Receipt has v2 fields: "
tail -1 "$STATE_DIR/t0_receipts.ndjson" | jq -e '.dispatch_id' > /dev/null && echo "✅" || echo "❌"

echo -n "4. Recommendations generated: "
[[ "$TOTAL" -gt 0 ]] && echo "✅" || echo "❌"

echo -n "5. T0 can see recommendations: "
echo "$OUTPUT" | grep -q "Recommendations" && echo "✅" || echo "❌"

# Cleanup
echo ""
echo "🧹 Cleaning up test files..."
rm -f "$DISPATCH_FILE" "$TEST_REPORT"

echo ""
echo "✅ Complete V2 Flow Test Finished"
echo ""
echo "📁 Check these files for details:"
echo "  • $STATE_DIR/t0_receipts.ndjson (last line)"
echo "  • $STATE_DIR/t0_recommendations.json"
echo "  • $STATE_DIR/cache/recommendations_last_hash.txt"
