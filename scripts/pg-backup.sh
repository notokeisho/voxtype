#!/bin/sh
# Dump the production PostgreSQL database to ./data/backups/postgres.
#
# The application only exports the global dictionary as xlsx, so users,
# whitelist entries and personal dictionaries live solely in the postgres
# volume. This script is the full-database backup.
#
# Usage: scripts/pg-backup.sh   (run from anywhere; paths resolve to the repo)
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

env_file=${ENV_FILE:-.env.prod}
if [ ! -f "$env_file" ]; then
    echo "env file not found: $env_file" >&2
    exit 1
fi

# shellcheck disable=SC1090
set -a
. "./$env_file"
set +a

backup_dir=${PG_BACKUP_DIR:-./data/backups/postgres}
retention_days=${PG_BACKUP_RETENTION_DAYS:-14}
mkdir -p "$backup_dir"

stamp=$(date +%Y%m%d-%H%M%S)
target="$backup_dir/voxtype-$stamp.sql.gz"

docker compose -f docker-compose.prod.yml --env-file "$env_file" exec -T db \
    pg_dump -U "${POSTGRES_USER:-voxtype}" -d "${POSTGRES_DB:-voxtype}" \
    | gzip > "$target"

# A dump that failed mid-stream leaves a short file behind; keep it out of the
# backup set so a later restore does not pick it up.
if [ ! -s "$target" ]; then
    echo "backup is empty, removing: $target" >&2
    rm -f "$target"
    exit 1
fi

find "$backup_dir" -name 'voxtype-*.sql.gz' -mtime "+$retention_days" -delete

echo "backup written: $target"
