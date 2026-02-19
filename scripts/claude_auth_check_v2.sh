#!/usr/bin/env bash
# Claude Code v2 authentication checker and setup helper
# Fixed for Claude Code 2.0.8+

set -euo pipefail

# Add NVM path if needed
export PATH="$HOME/.nvm/versions/node/v20.18.2/bin:$PATH"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔐 Checking Claude Code v2 authentication status..."

# Check if claude is available
if ! command -v claude &> /dev/null; then
    echo -e "${RED}❌ Claude CLI not found!${NC}"
    echo "Please install Claude CLI first"
    exit 1
fi

# Get Claude version
CLAUDE_VERSION=$(claude --version 2>&1 || echo "unknown")
echo -e "${BLUE}📌 Claude version: $CLAUDE_VERSION${NC}"

# Test authentication by trying to run a simple command with --print
# This will fail with "Missing API key" if not authenticated
AUTH_TEST=$(timeout 3s claude --print "echo test" 2>&1 || true)

# Check if we get the "Missing API key" error
if echo "$AUTH_TEST" | grep -q "Missing API key"; then
    echo -e "${YELLOW}⚠️  Claude authentication not configured${NC}"
    echo ""
    echo -e "${RED}The error 'Missing API key • Run /login' indicates you need to authenticate.${NC}"
    echo ""
    echo "To set up authentication, run ONE of the following:"
    echo ""
    echo -e "${GREEN}Option 1: Set up persistent token (recommended):${NC}"
    echo -e "  ${BLUE}claude setup-token${NC}"
    echo ""
    echo -e "${GREEN}Option 2: Use interactive login (temporary):${NC}"
    echo -e "  ${BLUE}claude${NC}"
    echo "  Then type: ${BLUE}/login${NC} in the Claude session"
    echo ""
    echo "The setup-token method is recommended as it persists across sessions."
    exit 1
elif echo "$AUTH_TEST" | grep -q "error" | grep -v "test"; then
    # Some other error occurred
    echo -e "${RED}❌ Error checking authentication:${NC}"
    echo "$AUTH_TEST"
    exit 1
else
    # Authentication appears to be working
    echo -e "${GREEN}✅ Claude Code is authenticated and ready!${NC}"
    echo ""
    echo "If you still see 'Missing API key' errors in terminals:"
    echo "1. Make sure each terminal inherits the correct environment"
    echo "2. Try running: SKIP_AUTH_CHECK=true ./VNX_HYBRID_FINAL.sh"
    echo "3. Or set up token with: claude setup-token"
    exit 0
fi