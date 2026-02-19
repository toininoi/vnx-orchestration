#!/bin/bash
# Intelligence queries for architect skill
# VNX Intelligence System access for architectural patterns and design solutions

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

# Architecture-specific query shortcuts
system_patterns() {
    patterns "system architecture $1"
}

microservice_patterns() {
    patterns "microservices $1"
}

event_patterns() {
    patterns "event-driven architecture $1"
}

security_patterns() {
    patterns "security architecture $1"
}

data_patterns() {
    patterns "data architecture $1"
}

# Usage examples
echo "Intelligence queries available:"
echo "  patterns 'event-driven architecture'"
echo "  tags 'architecture scalability security'"
echo "  keywords 'microservices kafka rabbitmq'"
echo "  prevention"
echo ""
echo "Architecture shortcuts:"
echo "  system_patterns 'distributed systems'"
echo "  microservice_patterns 'service mesh'"
echo "  event_patterns 'CQRS event sourcing'"
echo "  security_patterns 'zero trust'"
echo "  data_patterns 'data lake warehouse'"