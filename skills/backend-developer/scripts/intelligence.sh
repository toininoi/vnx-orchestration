#!/bin/bash
# Intelligence queries for backend-developer skill
# VNX Intelligence System access for proven patterns and solutions

INTEL_SCRIPT=".claude/vnx-system/scripts/gather_intelligence.py"

# Pattern Search - Find code patterns for specific tasks
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

# Backend-specific query shortcuts
api_patterns() {
    patterns "REST API endpoint $1"
}

db_patterns() {
    patterns "database $1"
}

auth_patterns() {
    patterns "authentication $1"
}

error_patterns() {
    patterns "error handling $1"
}

# Usage examples
echo "Intelligence queries available:"
echo "  patterns 'implement JWT authentication'"
echo "  tags 'api security validation'"
echo "  keywords 'fastapi pydantic'"
echo "  prevention"
echo ""
echo "Backend shortcuts:"
echo "  api_patterns 'validation'"
echo "  db_patterns 'optimization'"
echo "  auth_patterns 'JWT middleware'"
echo "  error_patterns 'centralized'"