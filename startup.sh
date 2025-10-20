#!/bin/bash

# Set up environment
export DISPLAY=:99

# Function to start ChromeDriver
start_chromedriver() {
    echo "Starting ChromeDriver..."
    
    # Kill any existing ChromeDriver processes
    pkill -f chromedriver 2>/dev/null || true
    sleep 2
    
    # Start ChromeDriver in background with logging
    nohup /usr/local/bin/chromedriver \
        --port=9515 \
        --log-path=/home/LogFiles/chromedriver.log \
        --verbose > /home/LogFiles/chromedriver-stdout.log 2>&1 &
    
    # Wait for ChromeDriver to start
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:9515/status > /dev/null; then
            echo "✓ ChromeDriver started successfully on port 9515 (attempt $attempt)"
            return 0
        fi
        
        echo "Waiting for ChromeDriver to start... (attempt $attempt/$max_attempts)"
        sleep 3
        ((attempt++))
    done
    
    echo "✗ Failed to start ChromeDriver after $max_attempts attempts"
    return 1
}

# Function to start Xvfb
start_xvfb() {
    echo "Starting Xvfb..."
    pkill -f Xvfb 2>/dev/null || true
    nohup Xvfb :99 -screen 0 1920x1080x24 > /home/LogFiles/xvfb.log 2>&1 &
    sleep 2
    echo "✓ Xvfb started"
}

# Clean up stale processes and profiles
echo "Cleaning up stale processes..."
pkill -f chrome 2>/dev/null || true
find /tmp/chrome-profiles -name "profile-*" -type d -mmin +30 -exec rm -rf {} + 2>/dev/null || true

# Ensure directories exist
mkdir -p /tmp/chrome-profiles
mkdir -p /home/LogFiles
chmod -R 777 /tmp/chrome-profiles /home/LogFiles

# Start required services
start_xvfb
start_chromedriver

# Verify services are running
echo "Verifying services..."
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
    echo "Check /home/LogFiles/chromedriver.log for errors"
fi

# Start the Azure startup process
echo "Starting Azure startup process..."
exec /opt/startup/startup.sh