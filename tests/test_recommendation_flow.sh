#!/usr/bin/env bash
# Test script to validate recommendation engine flow
# Creates a fake completion receipt to trigger recommendations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
STATE_DIR="$VNX_STATE_DIR"
DISPATCH_FILE="$VNX_DISPATCH_DIR/completed/20260114-091045-fc03e1cf-C.md"

echo "🧪 Testing Recommendation Engine Flow"
echo "======================================="

# Step 1: Verify v2 dispatch exists
if [[ ! -f "$DISPATCH_FILE" ]]; then
    echo "❌ Test dispatch not found: $DISPATCH_FILE"
    exit 1
fi

echo "✅ Found v2 test dispatch with On-Success/On-Failure fields"

# Step 2: Create a fake completion receipt for this dispatch
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%N" | cut -c1-26)
FAKE_RECEIPT=$(cat <<EOF
{
  "event_type": "task_complete",
  "timestamp": "${TIMESTAMP}+00:00",
  "terminal": "T3",
  "track": "C",
  "type": "IMPL",
  "gate": "implementation",
  "status": "success",
  "confidence": 0.95,
  "task_id": "html-clearing-opt-001",
  "dispatch_id": "20260114-091045-fc03e1cf-C",
  "report_path": "/test/report.md",
  "title": "HTML Memory Clearing Optimization Complete"
}
EOF
)

echo ""
echo "📝 Adding fake completion receipt via append_receipt.py..."
printf '%s' "$FAKE_RECEIPT" | python3 "$SCRIPT_DIR/append_receipt.py"

# Step 3: Run recommendation engine
echo ""
echo "🚀 Running recommendation engine..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vnx_paths.sh"
python3 "$SCRIPT_DIR/generate_t0_recommendations.py" --lookback 5

# Step 4: Check if recommendations were generated
echo ""
echo "📊 Checking results..."
if [[ -f "$STATE_DIR/t0_recommendations.json" ]]; then
    TOTAL=$(jq -r '.total_recommendations' "$STATE_DIR/t0_recommendations.json")
    if [[ "$TOTAL" -gt 0 ]]; then
        echo "✅ SUCCESS: Generated $TOTAL recommendations!"
        echo ""
        echo "Recommendations:"
        jq -r '.recommendations[] | "  • \(.trigger): \(.action) -> \(.gate) (\(.reason))"' "$STATE_DIR/t0_recommendations.json"

        echo ""
        echo "🎯 Testing T0 Intelligence Injection..."
        # Clear the hash cache to force update
        rm -f "$STATE_DIR/cache/recommendations_last_hash.txt"

        # Run the intelligence injection hook
        bash "$VNX_HOME/scripts/userpromptsubmit_intelligence_inject.sh"

        echo ""
        echo "✅ Complete flow tested successfully!"
    else
        echo "⚠️ No recommendations generated (check if dispatch has On-Success field)"
    fi
else
    echo "❌ Recommendations file not created"
fi

echo ""
echo "📁 Files to check:"
echo "  • t0_recommendations.json"
echo "  • t0_receipts.ndjson (last line)"
echo "  • cache/recommendations_last_hash.txt"
