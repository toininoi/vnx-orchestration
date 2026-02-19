#!/bin/bash
# Intelligence queries for api-developer skill
# VNX Intelligence System access for API patterns and RESTful solutions

INTEL_SCRIPT=".claude/vnx-system/scripts/gather_intelligence.py"

# Pattern Search - Find API patterns
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

# API-specific query shortcuts
rest_patterns() {
    patterns "REST API $1"
}

validation_patterns() {
    patterns "API validation $1"
}

auth_patterns() {
    patterns "API authentication $1"
}

rate_limit_patterns() {
    patterns "rate limiting $1"
}

# Usage examples
echo "Intelligence queries available:"
echo "  patterns 'REST API pagination'"
echo "  tags 'api security validation'"
echo "  keywords 'openapi swagger fastapi'"
echo "  prevention"
echo ""
echo "API shortcuts:"
echo "  rest_patterns 'CRUD operations'"
echo "  validation_patterns 'request body'"
echo "  auth_patterns 'JWT bearer'"
echo "  rate_limit_patterns 'token bucket'"