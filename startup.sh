#!/bin/bash

# Clean up any stale Chrome processes and profiles
echo "Cleaning up stale Chrome processes..."
pkill -f chrome 2>/dev/null || true
pkill -f chromedriver 2>/dev/null || true

# Wait a moment for processes to terminate
sleep 2

# Clean up old Chrome profiles
echo "Cleaning up stale Chrome profiles..."
find /tmp/chrome-profiles -name "profile-*" -type d -mmin +10 -exec rm -rf {} + 2>/dev/null || true

# Ensure Chrome profile directory exists and has proper permissions
mkdir -p /tmp/chrome-profiles
chmod -R 777 /tmp/chrome-profiles

# Start the existing Azure startup process
echo "Starting Azure startup process..."
exec /opt/startup/startup.sh