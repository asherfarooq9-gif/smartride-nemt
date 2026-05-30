#!/bin/sh
set -e

# Render gives postgres:// but asyncpg needs postgresql+asyncpg://
if [ -n "$DATABASE_URL" ]; then
  DATABASE_URL=$(echo "$DATABASE_URL" | sed 's|^postgres://|postgresql+asyncpg://|')
  export DATABASE_URL
fi

echo "Running Alembic migrations..."
alembic upgrade head

echo "Starting SmartRide API..."
exec uvicorn main:app --host 0.0.0.0 --port 8000
