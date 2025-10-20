#!/bin/bash

# Check if we've already started our services
if [ -f /tmp/services_started ]; then
    echo "Services already started, skipping initialization..."
    exec /opt/startup/startup.sh
    exit 0
fi

# Create marker file to prevent multiple starts
touch /tmp/services_started

echo "=== Starting Custom Services ==="

# Set up environment
export DISPLAY=:99

# Clean up any stale processes
echo "Cleaning up stale processes..."
pkill -f chromedriver 2>/dev/null || true
pkill -f Xvfb 2>/dev/null || true
sleep 2

# Clean up old Chrome profiles
find /tmp/chrome-profiles -name "profile-*" -type d -mmin +30 -exec rm -rf {} + 2>/dev/null || true

# Ensure directories exist
mkdir -p /tmp/chrome-profiles
chmod -R 777 /tmp/chrome-profiles

# Start Xvfb
echo "Starting Xvfb..."
nohup Xvfb :99 -screen 0 1920x1080x24 > /home/LogFiles/xvfb.log 2>&1 &
sleep 2

# Start ChromeDriver
echo "Starting ChromeDriver..."
nohup /usr/local/bin/chromedriver \
    --port=9515 \
    --log-path=/home/LogFiles/chromedriver.log \
    --verbose > /home/LogFiles/chromedriver-stdout.log 2>&1 &

# Wait for ChromeDriver to start
echo "Waiting for ChromeDriver to start..."
for i in {1..10}; do
    if curl -s http://localhost:9515/status > /dev/null; then
        echo "✓ ChromeDriver started successfully on port 9515"
        break
    fi
    echo "Attempt $i/10: Waiting for ChromeDriver..."
    sleep 3
done

# Verify services
echo "Verifying services:"
if pgrep -f "Xvfb" > /dev/null; then
    echo "✓ Xvfb is running"
else
    echo "✗ Xvfb is not running"
fi

if pgrep -f "chromedriver" > /dev/null; then
    echo "✓ ChromeDriver process is running"
else
    echo "✗ ChromeDriver process is not running"
fi

if curl -s http://localhost:9515/status > /dev/null; then
    echo "✓ ChromeDriver HTTP endpoint is accessible"
else
    echo "✗ ChromeDriver HTTP endpoint is not accessible"
fi

echo "=== Custom services started ==="

# Start the Azure startup process
echo "Starting Azure startup process..."
exec /opt/startup/startup.sh