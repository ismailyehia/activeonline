#!/bin/bash
set -e

# Render sends traffic to $PORT (defaults to 80)
PORT="${PORT:-80}"
sed -ri "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

echo "==> Caching config (uses Render environment variables)..."
php artisan config:clear
php artisan config:cache

echo "==> Running database migrations..."
php artisan migrate --force

echo "==> Seeding database (if needed)..."
php artisan db:seed --force

echo "==> Creating storage link..."
php artisan storage:link --force || true

chown -R www-data:www-data storage bootstrap/cache

echo "==> Starting Apache on port ${PORT}..."
exec apache2-foreground
