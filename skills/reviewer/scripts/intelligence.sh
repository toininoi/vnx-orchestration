#!/bin/bash
# Intelligence queries for reviewer skill
# VNX Intelligence System access for code review patterns and best practices

INTEL_SCRIPT=".claude/vnx-system/scripts/gather_intelligence.py"

# Pattern Search - Find review patterns
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

# Review-specific query shortcuts
security_patterns() {
    patterns "security vulnerability $1"
}

performance_patterns() {
    patterns "performance optimization $1"
}

quality_patterns() {
    patterns "code quality $1"
}

refactor_patterns() {
    patterns "refactoring $1"
}

# Usage examples
echo "Intelligence queries available:"
echo "  patterns 'code review best practices'"
echo "  tags 'security performance quality'"
echo "  keywords 'SOLID DRY KISS'"
echo "  prevention"
echo ""
echo "Review shortcuts:"
echo "  security_patterns 'SQL injection'"
echo "  performance_patterns 'database query'"
echo "  quality_patterns 'maintainability'"
echo "  refactor_patterns 'legacy code'"