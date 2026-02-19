#!/bin/bash
# List valid skills for T0 reference
# Usage: ./list_valid_skills.sh [--search TERM]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
SKILLS_YAML="$VNX_SKILLS_DIR/skills.yaml"

if [[ "$1" == "--search" ]]; then
    SEARCH_TERM="$2"
    echo "🔍 Searching for skill matching: $SEARCH_TERM"
    echo ""

    # Check valid skills
    MATCH=$(grep -A 20 "^valid_skills:" "$SKILLS_YAML" | grep -i "$SEARCH_TERM" | sed 's/^  - //')
    if [[ -n "$MATCH" ]]; then
        echo "✅ Valid skill: $MATCH"
        exit 0
    fi

    # Check common mistakes
    CORRECTION=$(grep -A 30 "^common_mistakes:" "$SKILLS_YAML" | grep -i "^  $SEARCH_TERM:" | sed 's/.*: //')
    if [[ -n "$CORRECTION" ]]; then
        echo "⚠️  '$SEARCH_TERM' is not valid"
        echo "✅ Use instead: $CORRECTION"
        exit 0
    fi

    echo "❌ No match found for '$SEARCH_TERM'"
    echo ""
    echo "💡 Tip: Run without --search to see all valid skills"
    exit 1
else
    echo "📋 Valid Skills (use EXACTLY these names)"
    echo "========================================"
    grep -A 20 "^valid_skills:" "$SKILLS_YAML" | grep "^  -" | sed 's/^  - /  ✓ /' | sed 's/ *#.*//'
    echo ""
    echo "💡 Tip: Use --search <term> to find a skill"
    echo "   Example: ./list_valid_skills.sh --search performance"
fi
