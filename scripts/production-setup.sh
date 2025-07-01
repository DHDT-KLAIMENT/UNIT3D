#!/usr/bin/env bash
# Production installation script for UNIT3D on Ubuntu/Debian
set -e

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

PROJECT_DIR="${1:-$(pwd)}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: $PROJECT_DIR is not a directory" >&2
    exit 1
fi

PHP_VERSION=8.4

# Install system packages
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:ondrej/php
apt-get update
apt-get install -y nginx mysql-server redis-server git curl unzip nodejs npm \
    php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-xml \
    php${PHP_VERSION}-mbstring php${PHP_VERSION}-curl php${PHP_VERSION}-zip \
    php${PHP_VERSION}-bcmath php${PHP_VERSION}-gd php${PHP_VERSION}-intl

# Install Composer
if ! command -v composer > /dev/null 2>&1; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

# Install Bun
if ! command -v bun > /dev/null 2>&1; then
    curl -fsSL https://bun.sh/install | bash -s -- --yes >/dev/null
    export BUN_INSTALL="${HOME}/.bun"
    export PATH="${BUN_INSTALL}/bin:$PATH"
fi

cd "$PROJECT_DIR"

# Ensure composer.json exists in the target directory
if [ ! -f composer.json ]; then
    echo "Error: composer.json not found in $PROJECT_DIR" >&2
    exit 1
fi

# Install PHP dependencies
export COMPOSER_ALLOW_SUPERUSER=1
composer install --no-dev --optimize-autoloader --no-interaction

# Prepare environment
[ -f .env ] || cp .env.example .env
php artisan key:generate --force

# Install JS dependencies and compile assets
bun install
bun run build

# Migrate database and cache configuration
php artisan migrate --force
php artisan set:all_cache

# Set file permissions
chown -R www-data:www-data "$PROJECT_DIR"
find "$PROJECT_DIR" -type f -exec chmod 664 {} \;
find "$PROJECT_DIR" -type d -exec chmod 775 {} \;
chgrp -R www-data storage bootstrap/cache
chmod -R ug+rwx storage bootstrap/cache

echo "UNIT3D installation completed"
