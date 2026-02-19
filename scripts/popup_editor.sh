#!/bin/bash
# Simple editor wrapper for tmux popup

file="$1"

# Try nano first (works best in popups)
if command -v nano >/dev/null 2>&1; then
    nano "$file"
# Fall back to vi with basic settings
elif command -v vi >/dev/null 2>&1; then
    vi -u NONE "$file"
else
    echo "No editor available!"
    exit 1
fi