#!/bin/bash
# Intelligence queries for test-engineer skill
# VNX Intelligence System access for testing patterns and QA solutions

INTEL_SCRIPT=".claude/vnx-system/scripts/gather_intelligence.py"

# Pattern Search - Find testing patterns
patterns() {
    python3 "$INTEL_SCRIPT" patterns "$1"
}

# Tag Search - Find solutions by category
tags() {
    python3 "$INTEL_SCRIPT" tags "$1"
}

# Keyword Search - Find by specific keywords
keywords() {
    python3 "$INTEL_SCRIPT" keywords "$1"
}

# Prevention Rules - Check for known anti-patterns
prevention() {
    python3 "$INTEL_SCRIPT" prevention
}

# Testing-specific query shortcuts
unit_patterns() {
    patterns "unit test $1"
}

integration_patterns() {
    patterns "integration test $1"
}

e2e_patterns() {
    patterns "E2E test $1"
}

mock_patterns() {
    patterns "mocking fixture $1"
}

# Usage examples
echo "Intelligence queries available:"
echo "  patterns 'pytest fixture parametrize'"
echo "  tags 'testing coverage mocking'"
echo "  keywords 'pytest unittest mock'"
echo "  prevention"
echo ""
echo "Testing shortcuts:"
echo "  unit_patterns 'async function'"
echo "  integration_patterns 'database'"
echo "  e2e_patterns 'user workflow'"
echo "  mock_patterns 'API response'"