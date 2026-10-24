#!/bin/sh
set -e

# Render gives postgres:// but asyncpg needs postgresql+asyncpg://
if [ -n "$DATABASE_URL" ]; then
  DATABASE_URL=$(echo "$DATABASE_URL" | sed 's|^postgres://|postgresql+asyncpg://|')
  export DATABASE_URL
fi

echo "Running Alembic migrations..."
alembic upgrade head

# Behind a reverse proxy set FORWARDED_ALLOW_IPS (uvicorn reads it) so the real
# client IP is used for rate limiting; the default trusts only 127.0.0.1.
echo "Starting SmartRide API..."
exec uvicorn main:app --host 0.0.0.0 --port 8000
