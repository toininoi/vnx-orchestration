#!/usr/bin/env bash
# MCP Profile Manager - CLI wrapper for mcp_profiles.py
# Manages per-terminal MCP server profiles to reduce memory usage.
#
# Usage:
#   ./mcp_profile_manager.sh generate-all    # Generate all terminal profiles
#   ./mcp_profile_manager.sh generate T1     # Generate for one terminal
#   ./mcp_profile_manager.sh show T1         # Show current profile
#   ./mcp_profile_manager.sh status          # Show all terminal profiles

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_PY="$SCRIPT_DIR/lib/mcp_profiles.py"

if [ ! -f "$PROFILES_PY" ]; then
    echo "ERROR: mcp_profiles.py not found at $PROFILES_PY" >&2
    exit 1
fi

command="${1:-help}"

case "$command" in
    generate-all)
        echo "Generating MCP profiles for all terminals..."
        python3 "$PROFILES_PY" generate-all
        echo ""
        echo "Done. Restart terminals to apply changes."
        ;;
    generate)
        terminal="${2:-}"
        if [ -z "$terminal" ]; then
            echo "Usage: $0 generate <T0|T1|T2|T3|T-MANAGER>" >&2
            exit 1
        fi
        python3 "$PROFILES_PY" generate "$terminal"
        echo "Restart $terminal to apply changes."
        ;;
    show)
        terminal="${2:-}"
        if [ -z "$terminal" ]; then
            echo "Usage: $0 show <T0|T1|T2|T3|T-MANAGER>" >&2
            exit 1
        fi
        python3 "$PROFILES_PY" show "$terminal"
        ;;
    status)
        echo "Current MCP profiles:"
        for t in T0 T1 T2 T3 T-MANAGER; do
            python3 "$PROFILES_PY" show "$t" 2>/dev/null || echo "  $t: not configured"
            echo ""
        done
        ;;
    help|--help|-h)
        echo "MCP Profile Manager - Reduce memory by limiting MCP servers per terminal"
        echo ""
        echo "Usage:"
        echo "  $0 generate-all          Generate .mcp.json for all terminals"
        echo "  $0 generate <terminal>   Generate .mcp.json for one terminal"
        echo "  $0 show <terminal>       Show current MCP profile"
        echo "  $0 status                Show all terminal profiles"
        echo ""
        echo "Terminals: T0, T1, T2, T3, T-MANAGER"
        echo ""
        echo "Profiles:"
        echo "  worker   - github, sequential-thinking only (T0, T1, T2, T-MANAGER)"
        echo "  mcp_hub  - All 10 servers (T3 only)"
        ;;
    *)
        echo "Unknown command: $command" >&2
        echo "Run '$0 help' for usage." >&2
        exit 1
        ;;
esac
