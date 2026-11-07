#!/usr/bin/env sh
# Postgres logical backup for SmartRide.
#
# Produces a timestamped pg_dump in custom format (-Fc), which is compressed and
# restorable selectively with pg_restore. Keeps the last $KEEP backups.
#
# Usage:
#   DATABASE_URL=postgresql://user:pass@host:5432/db ./scripts/db_backup.sh
#   ./scripts/db_backup.sh                 # falls back to the dev compose DB
#
# Restore the newest with: ./scripts/db_restore.sh
set -eu

# Splits DATABASE_URL into PG* variables so the password is not on the command line.
. "$(dirname "$0")/_pgenv.sh"
load_database_url

BACKUP_DIR="${BACKUP_DIR:-./backups}"
KEEP="${KEEP:-7}"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="${BACKUP_DIR}/smartride_${STAMP}.dump"

mkdir -p "$BACKUP_DIR"

echo "[backup] dumping ${DB_DISPLAY} to ${OUT}"
pg_dump --format=custom --no-owner --no-privileges --dbname="$DB_NAME" --file="$OUT"

SIZE="$(wc -c <"$OUT")"
if [ "$SIZE" -lt 100 ]; then
  echo "[backup] ERROR: dump is suspiciously small (${SIZE} bytes)" >&2
  exit 1
fi
echo "[backup] ok — ${SIZE} bytes"

# Retain only the newest $KEEP dumps.
ls -1t "${BACKUP_DIR}"/smartride_*.dump 2>/dev/null | tail -n +"$((KEEP + 1))" | while read -r old; do
  echo "[backup] pruning ${old}"
  rm -f "$old"
done

echo "[backup] done. ${OUT}"
