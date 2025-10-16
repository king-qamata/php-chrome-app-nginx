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
# Stage 2: PHP-FPM with Nginx
# ----------------------------
FROM php:8.1-fpm-bullseye

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx curl ca-certificates supervisor wget unzip jq openssh-server \
    libnss3 libgconf-2-4 libxi6 libgtk-3-0 libzip-dev zip \
    libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 \
    libcurl4-gnutls-dev pkg-config \
    && docker-php-ext-install zip curl mysqli pdo pdo_mysql \
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

# Configure SSH (on port 2222 as in your original)
RUN echo "root:Docker!" | chpasswd && \
    mkdir -p /var/run/sshd && \
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Create Azure Web App directory structure
RUN mkdir -p /home/site/wwwroot && \
    mkdir -p /home/LogFiles && \
    mkdir -p /home/data

# Copy application files from builder to Azure directory
COPY --from=builder /app/vendor /home/site/wwwroot/vendor
COPY src/ /home/site/wwwroot/
COPY composer.json /home/site/wwwroot/

# Set proper permissions for Azure directory
RUN chown -R www-data:www-data /home/site/wwwroot && \
    chmod -R 755 /home/site/wwwroot

# Copy PHP configuration
COPY php.ini /usr/local/etc/php/conf.d/custom.ini

# Copy NGINX configuration (updated for Azure path)
COPY nginx.conf /etc/nginx/nginx.conf

# Configure Supervisor to run NGINX, PHP-FPM, and SSH
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Allow environment variables from Azure to be visible in PHP
ENV CLEAR_ENV=no

# Set working directory to Azure path
WORKDIR /home/site/wwwroot

# Expose port 80 for web and 2222 for SSH
EXPOSE 80 2222

# Start Supervisor (which manages all processes)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]