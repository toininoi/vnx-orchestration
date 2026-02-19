#!/bin/bash
# Setup Daily Log Rotation via Cron
# Runs every day at 3:00 AM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/vnx_paths.sh
source "$SCRIPT_DIR/lib/vnx_paths.sh"
SCRIPT_PATH="$VNX_HOME/scripts/daily_log_rotation.sh"
CRON_ENTRY="0 3 * * * $SCRIPT_PATH >> $VNX_LOGS_DIR/daily_rotation.log 2>&1"

echo "Setting up daily log rotation cron job..."
echo ""
echo "This will run $SCRIPT_PATH every day at 3:00 AM"
echo ""

# Check if cron entry already exists
if crontab -l 2>/dev/null | grep -q "daily_log_rotation.sh"; then
    echo "⚠️  Cron job already exists!"
    echo ""
    echo "Current crontab:"
    crontab -l | grep "daily_log_rotation"
    echo ""
    read -p "Replace existing entry? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    # Remove old entry
    crontab -l | grep -v "daily_log_rotation.sh" | crontab -
fi

# Add new entry
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

echo "✓ Cron job installed!"
echo ""
echo "Schedule: Every day at 3:00 AM"
echo "Script: $SCRIPT_PATH"
echo "Log: $VNX_LOGS_DIR/daily_rotation.log"
echo ""
echo "Current crontab:"
crontab -l | grep "daily_log_rotation"
echo ""
echo "To verify: crontab -l"
echo "To remove: crontab -e (then delete the line)"
echo ""
echo "You can also run manually: $SCRIPT_PATH"
echo ""
