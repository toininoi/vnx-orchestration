#!/bin/bash
# Intelligence queries for frontend-developer skill
# VNX Intelligence System access for UI patterns and frontend solutions

INTEL_SCRIPT=".claude/vnx-system/scripts/gather_intelligence.py"

# Pattern Search - Find UI patterns
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

# Frontend-specific query shortcuts
component_patterns() {
    patterns "React component $1"
}

state_patterns() {
    patterns "state management $1"
}

accessibility_patterns() {
    patterns "accessibility ARIA $1"
}

responsive_patterns() {
    patterns "responsive design $1"
}

# Usage examples
echo "Intelligence queries available:"
echo "  patterns 'React hooks useEffect'"
echo "  tags 'frontend accessibility performance'"
echo "  keywords 'react typescript tailwind'"
echo "  prevention"
echo ""
echo "Frontend shortcuts:"
echo "  component_patterns 'modal dialog'"
echo "  state_patterns 'Redux context'"
echo "  accessibility_patterns 'screen reader'"
echo "  responsive_patterns 'mobile first'"