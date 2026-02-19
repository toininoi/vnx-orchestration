#!/bin/bash
# Intelligence queries for debugger skill
# VNX Intelligence System access for debugging patterns and root cause analysis

INTEL_SCRIPT=".claude/vnx-system/scripts/gather_intelligence.py"

# Pattern Search - Find debugging patterns
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

# Debugging-specific query shortcuts
error_patterns() {
    patterns "error exception $1"
}

performance_patterns() {
    patterns "performance bottleneck $1"
}

memory_patterns() {
    patterns "memory leak profiling $1"
}

root_cause_patterns() {
    patterns "root cause analysis $1"
}

# Usage examples
echo "Intelligence queries available:"
echo "  patterns 'debugging stack trace analysis'"
echo "  tags 'debugging profiling monitoring'"
echo "  keywords 'debugger breakpoint trace'"
echo "  prevention"
echo ""
echo "Debugging shortcuts:"
echo "  error_patterns 'null pointer'"
echo "  performance_patterns 'slow query'"
echo "  memory_patterns 'heap overflow'"
echo "  root_cause_patterns 'service timeout'"