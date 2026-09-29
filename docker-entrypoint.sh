#!/bin/bash
set -e

# Render sends traffic to $PORT (defaults to 80)
PORT="${PORT:-80}"
sed -ri "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

# ─── Aiven MySQL SSL certificate ───
# Aiven signs its MySQL certificate with its own CA, which is NOT in the
# system bundle (/etc/ssl/certs/ca-certificates.crt), so pointing
# MYSQL_ATTR_SSL_CA at the system bundle fails with "certificate verify failed".
# Put the contents of Aiven's ca.pem in the AIVEN_CA_CERT env var to verify it.
if [ -n "${AIVEN_CA_CERT}" ]; then
    printf '%s\n' "${AIVEN_CA_CERT}" > /var/www/html/storage/aiven-ca.pem
    chmod 644 /var/www/html/storage/aiven-ca.pem
    export MYSQL_ATTR_SSL_CA=/var/www/html/storage/aiven-ca.pem
    echo "==> Using Aiven CA certificate for MySQL SSL"
else
    unset MYSQL_ATTR_SSL_CA
    echo "==> AIVEN_CA_CERT not set: connecting without CA verification (same as the first deploy)"
fi

echo "==> Caching config (uses Render environment variables)..."
php artisan config:clear
php artisan config:cache

if [ "${DB_RESET_ON_DEPLOY}" = "true" ]; then
    # ONE-TIME USE: drops ALL tables in the database and rebuilds them.
    # Remove DB_RESET_ON_DEPLOY from Render right after this deploy succeeds,
    # otherwise every restart wipes the data.
    echo "==> !!! DB_RESET_ON_DEPLOY=true: dropping all tables and re-running migrations !!!"
    php artisan migrate:fresh --force
else
    echo "==> Running database migrations..."
    if ! php artisan migrate --force; then
        echo "==> Migration failed. If it says a table 'already exists', the database has"
        echo "==> tables but no migration history. Set DB_RESET_ON_DEPLOY=true in Render"
        echo "==> for ONE deploy to rebuild it (this deletes all data), then remove it."
        exit 1
    fi
fi

echo "==> Seeding database (if needed)..."
php artisan db:seed --force

echo "==> Creating storage link..."
php artisan storage:link --force || true

chown -R www-data:www-data storage bootstrap/cache

echo "==> Starting Apache on port ${PORT}..."
exec apache2-foreground
