# =========================
# Stage: app (php-fpm + code)
# =========================
FROM php:8.3-fpm-alpine AS app

# System deps
RUN apk add --no-cache \
    bash git curl ca-certificates busybox-extras \
    libpng-dev libjpeg-turbo-dev freetype-dev zlib-dev \
    oniguruma-dev libxml2-dev icu-dev \
    libzip-dev zip unzip \
    nodejs npm

# PHP extensions (incl. gd w/ jpeg + freetype)
RUN docker-php-ext-configure gd --with-jpeg --with-freetype \
 && docker-php-ext-install \
    pdo pdo_mysql mbstring exif pcntl bcmath intl opcache zip gd

# Raise PHP upload limits to accommodate large files
RUN { \
      echo 'upload_max_filesize=500M'; \
      echo 'post_max_size=500M'; \
    } > /usr/local/etc/php/conf.d/uploads.ini

# Composer
ENV COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_MEMORY_LIMIT=-1
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# App source
WORKDIR /var/www/html
COPY . /var/www/html

# Seed runtime storage defaults
COPY .docker/storage-seeds /var/www/html/.docker/storage-seeds

# Ensure .env exists BEFORE composer (artisan post-scripts expect it)
RUN if [ -f .env ]; then :; \
    elif [ -f .env.docker.example ]; then cp .env.docker.example .env; \
    else cp .env.example .env; fi

# During image build we do not have a database available. Swap to a
# temporary SQLite configuration so that artisan commands executed as part
# of composer scripts do not attempt to connect to MySQL. The original
# configuration is restored immediately after composer install completes.
RUN cp .env .env.dockerbuild \
 && php -r '$path=".env"; $env=file_get_contents($path); $env=preg_replace("/^DB_CONNECTION=.*/m", "DB_CONNECTION=sqlite", $env, 1, $c1); if(!$c1){$env.="\nDB_CONNECTION=sqlite";} $env=preg_replace("/^DB_DATABASE=.*/m", "DB_DATABASE=database/database.sqlite", $env, 1, $c2); if(!$c2){$env.="\nDB_DATABASE=database/database.sqlite";} file_put_contents($path, $env);' \
 && mkdir -p database \
 && touch database/database.sqlite

# Ensure Laravel cache directories exist before composer post-scripts run
RUN mkdir -p bootstrap/cache storage/framework/cache \
 && chmod -R ug+rwX bootstrap/cache storage/framework/cache

# PHP deps
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader \
 && mv .env.dockerbuild .env

# Frontend build (tolerant)
RUN [ -f package-lock.json ] && npm ci || true
RUN [ -f package.json ] && npm run build || true

# Laravel perms + storage symlink
RUN mkdir -p storage bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap public \
 && php artisan storage:link || true

# Ensure application code is owned by www-data
RUN chown -R www-data:www-data /var/www/html

# Entrypoint + helpers
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY docker/scripts/bootstrap.sh /usr/local/bin/bootstrap.sh
COPY docker/scripts/internal-db.sh /usr/local/bin/internal-db.sh
COPY docker/scripts/start-single.sh /usr/local/bin/start-single.sh
COPY docker/scripts/backup.sh /usr/local/bin/backup.sh
COPY docker/scripts/restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    /usr/local/bin/bootstrap.sh \
    /usr/local/bin/internal-db.sh \
    /usr/local/bin/start-single.sh \
    /usr/local/bin/backup.sh \
    /usr/local/bin/restore.sh

# Default command
CMD ["php-fpm", "-F"]


# =========================
# Stage: single (nginx + php-fpm + scheduler)
# =========================
FROM app AS single
ENV INTERNAL_DB=1 \
    DB_HOST=127.0.0.1
RUN apk add --no-cache nginx supervisor mariadb mariadb-client mariadb-backup \
 && mkdir -p /run/nginx /var/log/supervisor /run/mysqld /var/lib/mysql \
 && chown -R mysql:mysql /run/mysqld /var/lib/mysql
COPY nginx.single.conf /etc/nginx/nginx.conf
COPY docker/scripts/supervisord-single.conf /etc/supervisord.conf
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/local/bin/start-single.sh"]
