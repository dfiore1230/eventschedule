#!/usr/bin/env bash
set -euo pipefail

cd /workspace

# Prepare .env
cp .env.example .env || true
sed -i 's/DB_HOST=.*/DB_HOST=db/' .env || true
sed -i 's/DB_DATABASE=.*/DB_DATABASE=laravel_test/' .env || true
sed -i 's/DB_USERNAME=.*/DB_USERNAME=root/' .env || true
sed -i 's/DB_PASSWORD=.*/DB_PASSWORD=password/' .env || true

# Ensure APP_URL and APP_TESTING mirror CI
sed -i "s|APP_URL=.*|APP_URL=http://127.0.0.1:8000\nAPP_TESTING=true|" .env || true

# Wait for DB to be ready
for i in {1..30}; do
  if mysql -h db -uroot -ppassword -e "SELECT 1" >/dev/null 2>&1; then
    echo "DB is up"
    break
  fi
  echo "Waiting for DB... ($i)"
  sleep 2
done

# Install PHP and Node dependencies
composer install --no-interaction --prefer-dist
npm ci --no-audit --no-fund || npm install --no-audit --no-fund

# App setup
php artisan key:generate || true
php artisan migrate --force || true
php artisan storage:link || true

# Make test-results dir
mkdir -p storage/test-results

echo "Post-create complete. Run 'make up' to start services and 'make test' to run PHPUnit." 
