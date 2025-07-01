#!/usr/bin/env bash
# Production installation script for UNIT3D on Ubuntu/Debian
set -e

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

PROJECT_DIR="${1:-$(pwd)}"


# Install system packages
apt-get update
apt-get install -y nginx mysql-server redis-server git curl unzip nodejs npm \
    php8.3 php8.3-fpm php8.3-mysql php8.3-xml php8.3-mbstring \
    php8.3-curl php8.3-zip php8.3-bcmath php8.3-gd php8.3-intl

# Install Composer
if ! command -v composer > /dev/null 2>&1; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

# Install Bun
if ! command -v bun > /dev/null 2>&1; then
    curl -fsSL https://bun.sh/install | bash
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
composer install --no-dev --optimize-autoloader

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
