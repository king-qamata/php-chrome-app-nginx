# ----------------------------
# Stage 1: Composer Builder
# ----------------------------
FROM composer:2.5 AS builder
WORKDIR /app

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# ----------------------------
# Stage 2: Azure-optimized PHP-FPM with Nginx
# ----------------------------
FROM mcr.microsoft.com/appsvc/php:8.4-fpm_20250728.2.tuxprod

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install additional system dependencies (Chrome, ChromeDriver, etc.)
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    wget unzip jq \
    libnss3 libgconf-2-4 libxi6 libgtk-3-0 \
    libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN wget -qO /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get update && \
    apt-get install -y /tmp/google-chrome.deb && \
    rm -rf /tmp/google-chrome.deb

# Install ChromeDriver
RUN JSON_URL="https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json" && \
    DOWNLOAD_URL=$(curl -sSL $JSON_URL | jq -r '.channels.Stable.downloads.chromedriver[] | select(.platform == "linux64") | .url') && \
    wget -O /tmp/chromedriver.zip "$DOWNLOAD_URL" && \
    unzip /tmp/chromedriver.zip -d /tmp/ && \
    mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/ && \
    chmod +x /usr/local/bin/chromedriver && \
    rm -rf /tmp/*

# Copy application files from builder to Azure directory
COPY --from=builder /app/vendor /home/site/wwwroot/vendor
COPY src/ /home/site/wwwroot/
COPY composer.json /home/site/wwwroot/

# Set proper permissions for Azure directory (Azure images use a specific user)
RUN chmod -R 755 /home/site/wwwroot

# Copy custom PHP configuration if needed
# COPY php.ini /usr/local/etc/php/conf.d/999-custom.ini

# Note: Azure PHP image already includes:
# - Proper logging to /home/LogFiles
# - Correct PHP-FPM and nginx configuration
# - Startup script for Azure App Service
# - Health check endpoints

# The Azure PHP image already exposes port 80 and has the correct CMD
# We don't need to modify the entrypoint as Azure's image is already optimized