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
ENV DEBIAN_FRONTEND=noninteractive \
    PORT=80 \
    WEBSITES_PORT=80 \
    APPSETTING_WEBSITES_PORT=80

# Install additional system dependencies for Chrome
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip jq curl procps net-tools \
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
RUN echo "Chrome version:" && google-chrome --version && \
    echo "ChromeDriver version:" && chromedriver --version

# Create directories and set proper permissions
RUN mkdir -p /tmp/chrome-profiles && \
    mkdir -p /tmp/www-data && \
    mkdir -p /home/LogFiles && \
    chmod -R 777 /tmp/chrome-profiles /tmp/www-data /home/LogFiles && \
    chown -R www-data:www-data /tmp/www-data

# Fix home directory for www-data user
RUN usermod -d /tmp/www-data www-data

# Copy application files from builder to Azure directory
COPY --from=builder /app/vendor /home/site/wwwroot/vendor
COPY src/ /home/site/wwwroot/
COPY composer.json /home/site/wwwroot/

# Set proper permissions for Azure directory
RUN chown -R www-data:www-data /home/site/wwwroot && \
    chmod -R 755 /home/site/wwwroot

# Copy custom configuration files (if they exist)
# Note: Azure PHP image already has nginx and supervisor configured
# We'll override with our custom configurations if needed

# Copy custom nginx configuration if you have one
#COPY nginx-azure.conf /etc/nginx/sites-available/default 2>/dev/null || :

# Copy custom supervisor configuration for ChromeDriver
COPY supervisord-chromedriver.conf /etc/supervisor/conf.d/chromedriver.conf

# Copy custom PHP configuration if needed
COPY php-azure.ini /usr/local/etc/php/conf.d/999-custom.ini

# Create startup script for Chrome profile cleanup
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# Declare volume for Azure persistent storage
VOLUME ["/home"]

WORKDIR /home/site/wwwroot

#EXPOSE 80

# Use the existing Azure startup mechanism with our customizations
CMD ["/startup.sh"]