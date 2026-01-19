#!/usr/bin/env sh
set -e

if [ -z "${1:-}" ]; then
  echo "Usage: restore.sh /path/to/planify-backup-<timestamp>.tar.gz" >&2
  exit 1
fi

if [ "${CONFIRM_RESTORE:-}" != "yes" ]; then
  echo "Set CONFIRM_RESTORE=yes to proceed with restore." >&2
  exit 1
fi

backup_file="$1"
work_dir="$(mktemp -d)"

tar -C "${work_dir}" -xzf "${backup_file}"

if [ -f "${work_dir}/.env" ]; then
  cp "${work_dir}/.env" /var/www/html/.env
fi

if [ -f "${work_dir}/storage.tar.gz" ]; then
  tar -C /var/www/html -xzf "${work_dir}/storage.tar.gz"
fi

if [ -f "${work_dir}/public-images.tar.gz" ]; then
  tar -C /var/www/html -xzf "${work_dir}/public-images.tar.gz"
fi

db_restore=""
if command -v mariadb >/dev/null 2>&1; then
  db_restore="mariadb"
elif command -v mysql >/dev/null 2>&1; then
  db_restore="mysql"
fi

if [ -n "${db_restore}" ] && [ -f "${work_dir}/db.sql" ]; then
  : "${DB_HOST:=127.0.0.1}"
  : "${DB_PORT:=3306}"
  : "${DB_DATABASE:=planify}"
  : "${DB_USERNAME:=planify}"
  : "${DB_PASSWORD:=change_me}"
  MYSQL_PWD="${DB_PASSWORD}" "${db_restore}" \
    -h "${DB_HOST}" \
    -P "${DB_PORT}" \
    -u "${DB_USERNAME}" \
    "${DB_DATABASE}" < "${work_dir}/db.sql"
else
  echo "Warning: database restore tool not found or db.sql missing; skipping DB restore" >&2
fi

chown -R www-data:www-data /var/www/html/storage /var/www/html/public/images 2>/dev/null || true
chmod -R ug+rwX /var/www/html/storage 2>/dev/null || true

rm -rf "${work_dir}"

echo "Restore complete."
