#!/bin/sh
# Dump the production PostgreSQL database to ./data/backups/postgres.
#
# The application only exports the global dictionary as xlsx, so users,
# whitelist entries and personal dictionaries live solely in the postgres
# volume. This script is the full-database backup.
#
# Usage: scripts/pg-backup.sh   (run from anywhere; paths resolve to the repo)
set -eu

# The dump contains users, whitelist entries and dictionaries, so keep it
# readable only by the user running the backup.
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

env_file=${ENV_FILE:-.env.prod}
if [ ! -f "$env_file" ]; then
    echo "env file not found: $env_file" >&2
    exit 1
fi

backup_dir=${PG_BACKUP_DIR:-./data/backups/postgres}
retention_days=${PG_BACKUP_RETENTION_DAYS:-14}
mkdir -p "$backup_dir"

stamp=$(date +%Y%m%d-%H%M%S)
target="$backup_dir/voxtype-$stamp.sql.gz"
work="$backup_dir/.voxtype-$stamp.sql"

trap 'rm -f "$work"' EXIT

# Write the dump uncompressed first. A pipeline reports the exit status of its
# last command, so piping pg_dump straight into gzip would look successful even
# when pg_dump failed and gzip compressed an empty stream.
#
# Read the credentials from the container's own environment rather than
# sourcing the env file, which would execute whatever it contains.
docker compose -f docker-compose.prod.yml --env-file "$env_file" exec -T db \
    sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > "$work"

if [ ! -s "$work" ]; then
    echo "dump is empty, aborting" >&2
    exit 1
fi

gzip -c "$work" > "$target"

find "$backup_dir" -name 'voxtype-*.sql.gz' -mtime "+$retention_days" -delete

echo "backup written: $target"
