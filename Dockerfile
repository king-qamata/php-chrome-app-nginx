# ----------------------------
# Stage 1: Composer Builder
# ----------------------------
FROM composer:2.5 AS builder
WORKDIR /app

# Copy composer files
COPY composer.json ./

# Install dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# ----------------------------
# Stage 2: Azure-optimized PHP-FPM with Nginx
# ----------------------------
FROM mcr.microsoft.com/appsvc/php:8.3-fpm_20251016.4.tuxprod

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install additional system dependencies for Chrome
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip jq procps net-tools curl \
    libnss3 libgconf-2-4 libxi6 libgtk-3-0 \
    libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 \
    xvfb \
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

# Verify installations
RUN google-chrome --version && chromedriver --version

# Create directories and set proper permissions
RUN mkdir -p /tmp/chrome-profiles && \
    mkdir -p /tmp/www-data && \
    mkdir -p /home/LogFiles && \
    chmod -R 777 /tmp/chrome-profiles /tmp/www-data /home/LogFiles && \
    chown -R www-data:www-data /tmp/www-data

# Fix home directory permissions for www-data user
RUN usermod -d /tmp/www-data www-data

# Copy application files
COPY --from=builder /app/vendor /home/site/wwwroot/vendor
COPY src/ /home/site/wwwroot/
COPY composer.json /home/site/wwwroot/

# Set proper permissions
RUN chmod -R 755 /home/site/wwwroot

# Copy ChromeDriver initialization script to Azure startup directory
COPY init-chromedriver.sh /opt/startup/init-chromedriver.sh
RUN chmod +x /opt/startup/init-chromedriver.sh

# Declare volume for Azure persistent storage
VOLUME ["/home"]

WORKDIR /home/site/wwwroot

EXPOSE 80

# Use Azure's default startup process (it will automatically run our init script)
# Don't override CMD - let Azure use its default