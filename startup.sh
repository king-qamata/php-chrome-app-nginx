#!/bin/bash

# Set environment variables for Chrome
export HOME=/tmp/www-data
export XDG_CONFIG_HOME=/tmp/www-data/.config
export XDG_CACHE_HOME=/tmp/www-data/.cache
export XDG_DATA_HOME=/tmp/www-data/.local/share
export DISPLAY=:99

# Create necessary directories
mkdir -p /tmp/www-data/.config
mkdir -p /tmp/www-data/.cache
mkdir -p /tmp/www-data/.local/share
mkdir -p /tmp/chrome-profiles
mkdir -p /home/LogFiles

chown -R www-data:www-data /tmp/www-data
chmod -R 755 /tmp/www-data
chmod -R 777 /tmp/chrome-profiles /home/LogFiles

# Clean up any existing processes
echo "Cleaning up existing processes..."
pkill -f chromedriver 2>/dev/null || true
pkill -f Xvfb 2>/dev/null || true
pkill -f chrome 2>/dev/null || true
sleep 2

# Clean old profiles
find /tmp/chrome-profiles -name "profile-*" -type d -mmin +30 -exec rm -rf {} + 2>/dev/null || true

# Start Xvfb
echo "Starting Xvfb..."
nohup Xvfb :99 -screen 0 1920x1080x24 > /home/LogFiles/xvfb.log 2>&1 &
sleep 2

# Start ChromeDriver with proper error handling
echo "Starting ChromeDriver..."
nohup /usr/local/bin/chromedriver \
    --port=9515 \
    --whitelisted-ips= \
    --allowed-origins=* \
    --log-path=/home/LogFiles/chromedriver.log \
    --verbose > /home/LogFiles/chromedriver-stdout.log 2>&1 &

# Wait for ChromeDriver to start and verify it's working
echo "Waiting for ChromeDriver to start..."
for i in {1..15}; do
    # Check if process is running
    if ! pgrep -f "chromedriver" > /dev/null; then
        echo "ChromeDriver process died, check logs..."
        break
    fi
    
    # Check if port is listening
    if netstat -tuln 2>/dev/null | grep -q ":9515" || ss -tuln 2>/dev/null | grep -q ":9515"; then
        echo "Port 9515 is listening"
        
        # Check if HTTP endpoint responds
        if curl -s http://localhost:9515/status > /dev/null; then
            echo "✓ ChromeDriver started successfully on port 9515"
            break
        fi
    fi
    
    if [ $i -eq 15 ]; then
        echo "❌ ChromeDriver failed to start properly after 15 attempts"
        echo "Checking ChromeDriver logs..."
        tail -20 /home/LogFiles/chromedriver.log 2>/dev/null || echo "No ChromeDriver log found"
        echo "Checking ChromeDriver stdout..."
        tail -20 /home/LogFiles/chromedriver-stdout.log 2>/dev/null || echo "No ChromeDriver stdout found"
    else
        echo "Attempt $i/15: Waiting for ChromeDriver..."
        sleep 2
    fi
done

# Verify services are running
echo "Service status:"
if pgrep -f "Xvfb" > /dev/null; then
    echo "✓ Xvfb is running"
else
    echo "❌ Xvfb is not running"
fi

if pgrep -f "chromedriver" > /dev/null; then
    echo "✓ ChromeDriver process is running"
    echo "ChromeDriver PID: $(pgrep -f "chromedriver")"
else
    echo "❌ ChromeDriver process is not running"
fi

if netstat -tuln 2>/dev/null | grep -q ":9515" || ss -tuln 2>/dev/null | grep -q ":9515"; then
    echo "✓ Port 9515 is listening"
else
    echo "❌ Port 9515 is not listening"
fi

if curl -s http://localhost:9515/status > /dev/null; then
    echo "✓ ChromeDriver HTTP endpoint is accessible"
else
    echo "❌ ChromeDriver HTTP endpoint is not accessible"
fi

# Start the Azure startup process
#echo "Starting Azure startup process..."
#exec /opt/startup/startup.sh
service nginx reload