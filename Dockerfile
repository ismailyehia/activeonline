FROM php:8.3-apache

# ─── System dependencies ───
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev libjpeg-dev libfreetype6-dev \
    libzip-dev libxml2-dev libonig-dev \
    unzip curl \
    && rm -rf /var/lib/apt/lists/*

# ─── PHP extensions required by the project ───
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd zip mbstring pdo_mysql fileinfo dom xml opcache

# ─── PHP production settings ───
RUN echo "\
opcache.enable=1\n\
opcache.memory_consumption=128\n\
opcache.max_accelerated_files=10000\n\
opcache.validate_timestamps=0\n\
" > /usr/local/etc/php/conf.d/opcache-prod.ini

RUN echo "\
upload_max_filesize=12M\n\
post_max_size=15M\n\
memory_limit=256M\n\
max_execution_time=120\n\
" > /usr/local/etc/php/conf.d/app.ini

# ─── Composer ───
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ─── Apache config ───
RUN a2enmod rewrite headers
COPY docker/apache.conf /etc/apache2/sites-available/000-default.conf

# ─── App code ───
WORKDIR /var/www/html
COPY . .

# ─── Install dependencies (production) ───
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress

# ─── Laravel cache optimizations ───
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# ─── Permissions ───
RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# ─── Startup script ───
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
CMD ["docker-entrypoint.sh"]
