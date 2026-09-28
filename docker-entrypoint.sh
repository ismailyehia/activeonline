#!/bin/bash
set -e

echo "==> Running database migrations..."
php artisan migrate --force

echo "==> Seeding database (if needed)..."
php artisan db:seed --force

echo "==> Creating storage link..."
php artisan storage:link 2>/dev/null || true

echo "==> Starting Apache..."
apache2-foreground
