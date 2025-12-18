# php-chrome-app-nginx

Lightweight Docker image combining PHP-FPM, Nginx and Headless Chrome/Chromedriver for running PHP apps or automated browser tests.

## Features

- Nginx serving PHP via PHP-FPM
- Headless Chrome + Chromedriver included
- Supervisor to run multiple processes (Nginx, PHP-FPM, Chromedriver)
- Example PHP endpoints and a WebDriver test in `src/`

## Repository layout

- `Dockerfile` — primary Docker build
- `init-chromedriver.sh` — Chromedriver init helper
- `nginx.conf`, `nginx-azure.conf` — Nginx configuration
- `php.ini`, `php-azure.ini` — PHP configuration
- `supervisord.conf`, `supervisord-chromedriver.conf` — supervisor configs
- `src/` — example PHP endpoints and tests
  - `src/index.php` — basic entry
  - `src/diagnostic.php` — system diagnostic info
  - `src/webdriver_test.php` — example PHP WebDriver client test

## Quickstart

Build the Docker image from repository root:

```bash
docker build -t php-chrome-app-nginx .
```

Run the container:

```bash
docker run --rm -p 8080:80 --name php-chrome-app-nginx php-chrome-app-nginx
```

Open http://localhost:8080/ to view the app or call endpoints in `src/`.

## Using Docker Compose

Start with `docker-compose` (convenient for local development):

```bash
docker compose up --build -d
```

Stop and remove:

```bash
docker compose down
```

## Notes & Troubleshooting

- Supervisor starts multiple processes; check `supervisord.conf` for details.
- If Chrome/Chromedriver fails, check `init-chromedriver.sh` and supervisor logs.
- Ensure Chrome and Chromedriver versions match if you encounter version errors.

Inspect container and logs:

```bash
docker ps
docker logs -f <container-id-or-name>
docker exec -it <container-id-or-name> /bin/bash
```

## Contributing

Fork the repo, make changes, and open a PR. Update this README with any workflow or configuration changes.

## License

No license file included. Add a `LICENSE` to state terms.

## Files to inspect first

- [Dockerfile](Dockerfile)
- [supervisord.conf](supervisord.conf)
- [init-chromedriver.sh](init-chromedriver.sh)
- [src/index.php](src/index.php)

# ChromeDriver Automation Setup (Legacy Architecture)

> **DEPRECATED**: This document describes the legacy persistent ChromeDriver architecture. For the current on-demand architecture, please refer to the [main README.md](../README.md).

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Migration to New Architecture](#migration-to-new-architecture)

## Overview

This legacy setup uses a **persistent ChromeDriver service** running on port 9515, managed by Supervisor. All PHP scripts connect to this single shared ChromeDriver instance. This architecture was deprecated due to scalability issues and port conflicts.

### Deprecation Notice
⚠️ **This architecture is no longer recommended** and has been replaced by an on-demand ChromeDriver instance approach. The persistent service model has several limitations:
- Port conflicts when multiple applications try to use ChromeDriver
- Resource contention between different scripts
- Difficult to scale horizontally
- Single point of failure

## Architecture

### System Diagram
```
┌─────────────────────────────────────────────────────┐
│                Azure App Service                    │
├─────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────┐  │
│  │               Supervisor                     │  │
│  │  ┌──────────────────────────────────────┐  │  │
│  │  │     ChromeDriver Service             │  │  │
│  │  │     Port: 9515 (Fixed)              │  │  │
│  │  │     Managed by Supervisor           │  │  │
│  │  └───────────────────┬──────────────────┘  │  │
│  │                      │                      │  │
│  └──────────────────────┼──────────────────────┘  │
│                         │                         │
│    ┌────────────────────┴─────────────────────┐   │
│    │              Xvfb (:99)                  │   │
│    │        Virtual Display Server            │   │
│    └────────────────────┬─────────────────────┘   │
│                         │                         │
│  ┌──────────────────────┼──────────────────────┐  │
│  │      PHP-FPM         │     Nginx            │  │
│  │  ┌──────────────┐    │  ┌──────────────┐   │  │
│  │  │ Script 1     ├────┼──┤   Reverse    │   │  │
│  │  │ Script 2     │    │  │   Proxy      │   │  │
│  │  │ Script 3     │    │  └──────────────┘   │  │
│  │  └──────────────┘    │                      │  │
│  └──────────────────────┼──────────────────────┘  │
│                         │                         │
│  ┌──────────────────────┼──────────────────────┐  │
│  │     Chrome Browser   │   Chrome Profiles    │  │
│  │  ┌────────────────┐  │  ┌────────────────┐  │  │
│  │  │ Instance 1     │  │  │ Profile 1      │  │  │
│  │  │ Instance 2     │  │  │ Profile 2      │  │  │
│  │  │ Instance 3     │  │  │ Profile 3      │  │  │
│  │  └────────────────┘  │  └────────────────┘  │  │
│  └──────────────────────┴──────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Key Components
1. **ChromeDriver Service**: Persistent service running on port 9515
2. **Supervisor**: Process control system managing ChromeDriver
3. **Xvfb**: Virtual display server for headless Chrome
4. **PHP-FPM**: PHP FastCGI Process Manager
5. **Nginx**: Web server with reverse proxy
6. **Shared Profiles**: Chrome user profiles in `/tmp/chrome-profiles/`

## Prerequisites

### System Requirements
- **Azure App Service**: Linux (PHP 8.3)
- **Memory**: Minimum 1GB RAM
- **Storage**: 500MB free space in `/tmp`

### Software Dependencies
- Google Chrome (Latest stable)
- ChromeDriver (Matching version)
- Supervisor 4.x
- Xvfb (X Virtual Framebuffer)
- PHP 8.3+ with Composer

## Installation

### 1. Dockerfile (Legacy)

```dockerfile
# ----------------------------
# Stage 1: Composer Builder
# ----------------------------
FROM composer:2.5 AS builder
WORKDIR /app
COPY composer.json ./
RUN composer install --no-dev --optimize-autoloader

# ----------------------------
# Stage 2: Azure PHP with Chrome
# ----------------------------
FROM mcr.microsoft.com/appsvc/php:8.3-fpm_20251016.4.tuxprod

ENV DEBIAN_FRONTEND=noninteractive \
    PORT=80 \
    WEBSITES_PORT=80

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget unzip curl jq supervisor \
    libnss3 libgconf-2-4 libxi6 libgtk-3-0 \
    libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 \
    xvfb \
    && apt-get clean

# Install Google Chrome
RUN wget -qO /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y /tmp/google-chrome.deb \
    && rm -rf /tmp/google-chrome.deb

# Install ChromeDriver (matching Chrome version)
RUN CHROME_VERSION=$(google-chrome --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+') \
    && CHROME_MAJOR=$(echo $CHROME_VERSION | cut -d'.' -f1) \
    && wget -O /tmp/chromedriver.zip "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$CHROME_MAJOR" \
    && unzip /tmp/chromedriver.zip -d /tmp/ \
    && mv /tmp/chromedriver /usr/local/bin/ \
    && chmod +x /usr/local/bin/chromedriver \
    && rm -rf /tmp/*

# Create directories
RUN mkdir -p /tmp/chrome-profiles \
    && mkdir -p /tmp/www-data \
    && mkdir -p /home/LogFiles \
    && chmod -R 777 /tmp/chrome-profiles /tmp/www-data /home/LogFiles \
    && chown -R www-data:www-data /tmp/www-data \
    && usermod -d /tmp/www-data www-data

# Copy application
COPY --from=builder /app/vendor /home/site/wwwroot/vendor
COPY src/ /home/site/wwwroot/
COPY composer.json /home/site/wwwroot/

# Copy Supervisor configuration
COPY supervisord-chromedriver.conf /etc/supervisor/conf.d/
COPY php-azure.ini /usr/local/etc/php/conf.d/999-custom.ini
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

WORKDIR /home/site/wwwroot
CMD ["/startup.sh"]
```

### 2. Supervisor Configuration

**`supervisord-chromedriver.conf`**:
```ini
[program:chromedriver]
command=/usr/local/bin/chromedriver --port=9515 --log-path=/home/LogFiles/chromedriver.log --verbose
autostart=true
autorestart=true
startretries=3
startsecs=5
stdout_logfile=/home/LogFiles/chromedriver-stdout.log
stdout_logfile_maxbytes=0
stderr_logfile=/home/LogFiles/chromedriver-stderr.log
stderr_logfile_maxbytes=0
environment=DISPLAY=":99"
```

### 3. Startup Script

**`startup.sh`**:
```bash
#!/bin/bash

# Set environment variables
export HOME=/tmp/www-data
export DISPLAY=:99

# Create directories
mkdir -p /tmp/www-data/.config
mkdir -p /tmp/www-data/.cache
mkdir -p /tmp/www-data/.local/share
mkdir -p /tmp/chrome-profiles
mkdir -p /home/LogFiles

chown -R www-data:www-data /tmp/www-data
chmod -R 755 /tmp/www-data
chmod -R 777 /tmp/chrome-profiles /home/LogFiles

# Clean up existing processes
pkill -f Xvfb 2>/dev/null || true
sleep 2

# Start Xvfb
echo "Starting Xvfb..."
nohup Xvfb :99 -screen 0 1920x1080x24 > /home/LogFiles/xvfb.log 2>&1 &
sleep 2

# Start Supervisor (manages ChromeDriver)
echo "Starting Supervisor..."
supervisord -c /etc/supervisor/supervisord.conf

# Wait for ChromeDriver to start
echo "Waiting for ChromeDriver..."
for i in {1..15}; do
    if curl -s http://localhost:9515/status > /dev/null; then
        echo "✓ ChromeDriver started on port 9515"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "❌ ChromeDriver failed to start"
        exit 1
    fi
    sleep 2
done

# Start Azure services
exec /opt/startup/startup.sh
```

## Configuration

### PHP Configuration (`php-azure.ini`)
```ini
memory_limit = 512M
max_execution_time = 180
max_input_time = 90
display_errors = Off
log_errors = On
```

### Environment Variables
```bash
# Required
HOME=/tmp/www-data
DISPLAY=:99

# ChromeDriver Service
CHROMEDRIVER_PORT=9515
CHROMEDRIVER_LOG_LEVEL=INFO
```

## Usage

### Connecting to Persistent ChromeDriver

```php
<?php
require __DIR__ . '/vendor/autoload.php';

use Facebook\WebDriver\Remote\RemoteWebDriver;
use Facebook\WebDriver\Chrome\ChromeOptions;
use Facebook\WebDriver\Remote\DesiredCapabilities;

// Set environment
putenv('HOME=/tmp/www-data');
putenv('DISPLAY=:99');

try {
    // Create Chrome options
    $options = new ChromeOptions();
    $options->addArguments([
        '--headless',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--window-size=1920,1080',
        '--user-data-dir=/tmp/chrome-profiles/profile-' . uniqid()
    ]);
    
    // Create capabilities
    $capabilities = DesiredCapabilities::chrome();
    $capabilities->setCapability(ChromeOptions::CAPABILITY, $options);
    
    // Connect to persistent ChromeDriver service
    $driver = RemoteWebDriver::create(
        'http://localhost:9515',
        $capabilities,
        5000, // Connection timeout
        30000 // Request timeout
    );
    
    // Use the browser
    $driver->get('https://example.com');
    echo "Title: " . $driver->getTitle();
    
    // IMPORTANT: Close session but keep ChromeDriver running
    $driver->quit();
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage();
}
```

### Multiple Scripts Sharing Same Service

```php
<?php
// Script 1: Creates first session
$driver1 = RemoteWebDriver::create('http://localhost:9515', $capabilities1);
$driver1->get('https://site1.com');

// Script 2: Creates second session (runs concurrently)
$driver2 = RemoteWebDriver::create('http://localhost:9515', $capabilities2);
$driver2->get('https://site2.com');

// Both scripts share the same ChromeDriver service
// but have isolated browser sessions
```

### Session Management

```php
<?php
class ChromeSession {
    private $driver;
    private $sessionId;
    
    public function __construct($capabilities) {
        $this->driver = RemoteWebDriver::create(
            'http://localhost:9515',
            $capabilities
        );
        $this->sessionId = $this->driver->getSessionID();
    }
    
    public function reuseSession($sessionId) {
        // Reuse existing session (advanced usage)
        $this->driver = RemoteWebDriver::createBySessionID(
            $sessionId,
            'http://localhost:9515'
        );
    }
    
    public function close() {
        if ($this->driver) {
            $this->driver->quit();
        }
    }
}
```

## Maintenance

### Monitoring the Service

```bash
# Check Supervisor status
supervisorctl status

# Check ChromeDriver process
ps aux | grep chromedriver

# Check ChromeDriver logs
tail -f /home/LogFiles/chromedriver.log

# Check service health
curl http://localhost:9515/status
```

### Restarting ChromeDriver

```bash
# Restart via Supervisor
supervisorctl restart chromedriver

# Manual restart
pkill chromedriver
/usr/local/bin/chromedriver --port=9515 --log-path=/home/LogFiles/chromedriver.log &
```

### Cleaning Up

```bash
# Clean old Chrome profiles
find /tmp/chrome-profiles -name "profile-*" -type d -mmin +60 -exec rm -rf {} \;

# Clean log files
find /home/LogFiles -name "*.log" -type f -mtime +7 -exec rm -f {} \;

# Check disk usage
du -sh /tmp/chrome-profiles
```

## Troubleshooting

### Common Issues

#### 1. ChromeDriver Service Not Starting
```bash
# Check Supervisor logs
supervisorctl tail -f chromedriver stderr

# Check ChromeDriver executable
ls -la /usr/local/bin/chromedriver
/usr/local/bin/chromedriver --version

# Check port availability
netstat -tuln | grep :9515
```

#### 2. Connection Refused Errors
```php
// PHP Error: Connection refused on port 9515
try {
    $driver = RemoteWebDriver::create('http://localhost:9515', $capabilities);
} catch (WebDriverException $e) {
    // Check if service is running
    $isRunning = shell_exec("netstat -tuln | grep :9515");
    if (!$isRunning) {
        echo "ChromeDriver service is not running";
        // Restart service
        shell_exec("supervisorctl restart chromedriver");
    }
}
```

#### 3. Chrome Crashes Frequently
```bash
# Increase shared memory
$options->addArguments(['--disable-dev-shm-usage']);

# Reduce memory usage
$options->addArguments([
    '--disable-images',
    '--disable-javascript',
    '--single-process'
]);

# Check system memory
free -h
```

#### 4. Profile Directory Issues
```bash
# Fix permissions
chmod 777 /tmp/chrome-profiles
chown www-data:www-data /tmp/www-data

# Clean corrupted profiles
rm -rf /tmp/chrome-profiles/profile-*
```

### Diagnostic Commands

```bash
# Full system check
./diagnostic.php

# Check Chrome version
google-chrome --version

# Check ChromeDriver version
chromedriver --version

# Check running processes
ps aux | grep -E "(chrome|chromedriver|Xvfb|supervisor)"

# Check network connections
netstat -tuln | grep :9515

# Check disk space
df -h /tmp

# Check log files
ls -la /home/LogFiles/*.log
```

### Error Codes and Solutions

| Error Code | Description | Solution |
|------------|-------------|----------|
| ERR_CONNECTION_REFUSED | Can't connect to port 9515 | Start ChromeDriver service |
| ERR_TIMED_OUT | Connection timeout | Increase timeout, check memory |
| ERR_PROFILE_DIR | Can't create profile | Fix /tmp permissions |
| ERR_CHROME_CRASH | Chrome process died | Check Xvfb, increase memory |

## Migration to New Architecture

### Why Migrate?

The persistent architecture has several limitations that make migration necessary:

1. **Port Conflicts**: Only one service can run on port 9515
2. **Resource Contention**: All scripts share the same ChromeDriver process
3. **Scalability Issues**: Difficult to run multiple ChromeDriver instances
4. **Maintenance Complexity**: Service management requires Supervisor

### Migration Steps

#### Step 1: Update Dockerfile
Remove Supervisor and persistent service setup:
```dockerfile
# Remove these lines:
RUN apt-get install -y supervisor
COPY supervisord-chromedriver.conf /etc/supervisor/conf.d/
```

#### Step 2: Update startup.sh
Remove ChromeDriver service startup:
```bash
# Remove these sections:
# Start Supervisor
# Wait for ChromeDriver to start
# ChromeDriver health check
```

#### Step 3: Update PHP Code
Change from persistent to on-demand:
```php
// OLD: Persistent service
$driver = RemoteWebDriver::create('http://localhost:9515', $capabilities);

// NEW: On-demand instance
$driver = ChromeDriver::start($capabilities);
```

#### Step 4: Test Migration
Run diagnostic scripts to verify:
```bash
php new_diagnostic.php
php simple_test.php
```

### Migration Checklist

- [ ] Remove Supervisor configuration
- [ ] Update startup.sh script
- [ ] Convert PHP code to use ChromeDriver::start()
- [ ] Test basic functionality
- [ ] Monitor resource usage
- [ ] Update documentation

### Rollback Procedure

If migration fails, revert to old architecture:

1. Restore original Dockerfile
2. Restore original startup.sh
3. Restart container
4. Verify service on port 9515

---

## Appendix

### Legacy Configuration Files

All legacy configuration files are available in the `legacy/` directory:
- `legacy/Dockerfile` - Original Docker configuration
- `legacy/supervisord-chromedriver.conf` - Supervisor config
- `legacy/startup-legacy.sh` - Original startup script
- `legacy/php-azure-legacy.ini` - Original PHP config

### Compatibility Notes

This legacy architecture is compatible with:
- Facebook WebDriver PHP library v1.x
- Chrome 90-120
- PHP 7.4-8.3
- Azure App Service Linux

### Known Limitations

1. **Maximum Concurrent Sessions**: Limited by single ChromeDriver process
2. **Memory Leaks**: Chrome processes may not clean up properly
3. **Port Conflicts**: Cannot run other services on port 9515
4. **Service Dependencies**: Requires Supervisor and Xvfb

### Support Timeline

- **Active Support**: Ended December 2023
- **Security Updates**: Ended June 2024
- **Complete Deprecation**: December 2024

---

## Disclaimer

This legacy architecture is provided for reference purposes only. New projects should use the on-demand ChromeDriver architecture described in the main README.md. The deprecated architecture may have security vulnerabilities and is not recommended for production use.

---

*Last Updated: December 2024*  
*Status: DEPRECATED*  
*Replaced By: On-Demand ChromeDriver Architecture*