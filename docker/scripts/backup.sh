#!/usr/bin/env sh
set -e

backup_dir="${BACKUP_DIR:-/var/www/html/storage/backups}"
timestamp="$(date -u +%Y%m%d-%H%M%S)"
work_dir="$(mktemp -d)"
backup_file="${backup_dir}/planify-backup-${timestamp}.tar.gz"

mkdir -p "${backup_dir}"

if [ -f /var/www/html/.env ]; then
  cp /var/www/html/.env "${work_dir}/.env"
fi

tar -C /var/www/html -czf "${work_dir}/storage.tar.gz" storage

if [ -d /var/www/html/public/images ]; then
  tar -C /var/www/html -czf "${work_dir}/public-images.tar.gz" public/images
fi

db_dump=""
if command -v mariadb-dump >/dev/null 2>&1; then
  db_dump="mariadb-dump"
elif command -v mysqldump >/dev/null 2>&1; then
  db_dump="mysqldump"
fi

if [ -n "${db_dump}" ]; then
  : "${DB_HOST:=127.0.0.1}"
  : "${DB_PORT:=3306}"
  : "${DB_DATABASE:=planify}"
  : "${DB_USERNAME:=planify}"
  : "${DB_PASSWORD:=change_me}"
  MYSQL_PWD="${DB_PASSWORD}" "${db_dump}" \
    -h "${DB_HOST}" \
    -P "${DB_PORT}" \
    -u "${DB_USERNAME}" \
    "${DB_DATABASE}" > "${work_dir}/db.sql"
else
  echo "Warning: database dump tool not found; skipping DB backup" >&2
fi

tar -C "${work_dir}" -czf "${backup_file}" .
rm -rf "${work_dir}"

echo "Backup written to ${backup_file}"
