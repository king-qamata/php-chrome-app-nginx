#!/bin/bash

# This script will be called by Azure's startup process
# It runs after the main services are started

echo "=== Initializing ChromeDriver ==="

# Set environment variables to prevent Chrome from using /var/www as home
export HOME=/tmp/www-data
export XDG_CONFIG_HOME=/tmp/www-data/.config
export XDG_CACHE_HOME=/tmp/www-data/.cache
export XDG_DATA_HOME=/tmp/www-data/.local/share

# Create necessary directories
mkdir -p /tmp/www-data/.config
mkdir -p /tmp/www-data/.cache
mkdir -p /tmp/www-data/.local/share
chown -R www-data:www-data /tmp/www-data
chmod -R 755 /tmp/www-data

# Only run if ChromeDriver is not already running
if ! pgrep -f "chromedriver" > /dev/null; then
    echo "Starting ChromeDriver services..."
    
    # Set up environment
    export DISPLAY=:99
    
    # Clean up
    pkill -f chromedriver 2>/dev/null || true
    pkill -f Xvfb 2>/dev/null || true
    sleep 2
    
    # Clean old profiles
    find /tmp/chrome-profiles -name "profile-*" -type d -mmin +30 -exec rm -rf {} + 2>/dev/null || true
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
    
    # Wait for startup
    for i in {1..10}; do
        if curl -s http://localhost:9515/status > /dev/null; then
            echo "✓ ChromeDriver started on port 9515"
            break
        fi
        sleep 3
    done
else
    echo "ChromeDriver is already running"
fi

echo "=== ChromeDriver initialization complete ==="