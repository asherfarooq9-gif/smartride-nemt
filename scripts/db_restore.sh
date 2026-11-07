#!/usr/bin/env sh
# Restore a SmartRide pg_dump produced by db_backup.sh.
#
# Usage:
#   ./scripts/db_restore.sh                       # newest dump in ./backups
#   ./scripts/db_restore.sh ./backups/smartride_20260612_101500.dump
#   DATABASE_URL=postgresql://user:pass@host/db ./scripts/db_restore.sh <file>
#
# Safety: refuses to run unless CONFIRM=yes, because --clean drops existing
# objects before recreating them.
set -eu

# Splits DATABASE_URL into PG* variables so the password is not on the command line
# or in the prompt below.
. "$(dirname "$0")/_pgenv.sh"
load_database_url

BACKUP_DIR="${BACKUP_DIR:-./backups}"
FILE="${1:-}"
if [ -z "$FILE" ]; then
  FILE="$(ls -1t "${BACKUP_DIR}"/smartride_*.dump 2>/dev/null | head -n 1 || true)"
fi
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "[restore] ERROR: no dump file found (looked in ${BACKUP_DIR})" >&2
  exit 1
fi

if [ "${CONFIRM:-}" != "yes" ]; then
  echo "[restore] About to --clean restore ${FILE} into:" >&2
  echo "          ${DB_DISPLAY}" >&2
  echo "[restore] This DROPS and recreates existing objects." >&2
  echo "[restore] Re-run with CONFIRM=yes to proceed." >&2
  exit 1
fi

echo "[restore] restoring ${FILE}"
# --clean --if-exists makes the restore idempotent; --exit-on-error catches a
# genuinely broken dump instead of silently leaving a half-restored DB.
pg_restore --clean --if-exists --no-owner --no-privileges \
  --exit-on-error --dbname="$DB_NAME" "$FILE"

echo "[restore] done."
