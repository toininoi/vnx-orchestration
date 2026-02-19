#!/bin/bash
# Intelligence queries for planner skill
# VNX Intelligence System access for architectural patterns and planning insights

INTEL_SCRIPT=".claude/vnx-system/scripts/gather_intelligence.py"

# Pattern Search - Find architectural patterns
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

# Planning-specific query shortcuts
architecture_patterns() {
    patterns "architecture $1"
}

design_patterns() {
    patterns "design pattern $1"
}

integration_patterns() {
    patterns "integration $1"
}

scaling_patterns() {
    patterns "scaling strategy $1"
}

# Usage examples
echo "Intelligence queries available:"
echo "  patterns 'microservices architecture'"
echo "  tags 'architecture scalability performance'"
echo "  keywords 'event-driven kafka'"
echo "  prevention"
echo ""
echo "Planning shortcuts:"
echo "  architecture_patterns 'microservices'"
echo "  design_patterns 'factory pattern'"
echo "  integration_patterns 'API gateway'"
echo "  scaling_patterns 'horizontal scaling'"