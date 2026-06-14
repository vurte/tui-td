#!/bin/bash
# Check for new tans-parser versions and integrate if found
# Called by crontab every 15 minutes

set -e

cd /Users/halukdurmus/Development/tui-td

# Get the latest tans-parser version
LATEST=$(gem search tans-parser --remote --exact 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1)
CURRENT=$(grep "tans-parser" Gemfile.lock | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

echo "$(date): Latest tans-parser: $LATEST, Current: $CURRENT"

if [ "$LATEST" != "$CURRENT" ] && [ -n "$LATEST" ]; then
    echo "$(date): New version $LATEST detected! Triggering integration..."
    # Write a trigger file for the next claude session to pick up
    echo "$LATEST" > /tmp/tui_td_tans_parser_update_trigger
fi

exit 0
