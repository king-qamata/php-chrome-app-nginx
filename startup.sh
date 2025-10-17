#!/bin/bash

# Clean up any stale Chrome profiles on startup
find /tmp/chrome-profiles -name "*" -type d -mmin +30 -exec rm -rf {} + 2>/dev/null || true

# Ensure Chrome profile directory exists and has proper permissions
mkdir -p /tmp/chrome-profiles
chmod -R 777 /tmp/chrome-profiles

# Start the existing Azure startup process
exec /opt/startup/startup.sh