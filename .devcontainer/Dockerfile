FROM php:8.3-cli-bullseye

# Install system dependencies, Node 18, Chromium and drivers
RUN export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get -y install --no-install-recommends \
    git \
    unzip \
    zip \
    libzip-dev \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    default-mysql-client \
    chromium \
    chromium-driver \
    ca-certificates \
    curl \
    gnupg2 \
  && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
  && apt-get -y install nodejs build-essential libfreetype6-dev libjpeg62-turbo-dev \
  && npm i -g npm@latest \
  && docker-php-ext-configure gd --with-freetype --with-jpeg || true \
  && docker-php-ext-install pdo_mysql bcmath intl gd zip || true \
  && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install Composer
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
  && composer --version
