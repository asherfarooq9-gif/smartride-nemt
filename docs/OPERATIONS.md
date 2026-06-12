# Operations — Backup/Restore, Pooling, Staging

Operational runbook for running SmartRide beyond a laptop.

## Database backup & restore

Scripts in `scripts/`. Both accept `DATABASE_URL` (the SQLAlchemy `+asyncpg`
suffix is stripped automatically) and default to the dev compose DB.

### Backup

```bash
DATABASE_URL=postgresql://user:pass@host:5432/smartride ./scripts/db_backup.sh
```

- `pg_dump --format=custom` (compressed, selectively restorable).
- Timestamped into `./backups/` (override with `BACKUP_DIR`).
- Retains the newest `KEEP` dumps (default 7); older ones are pruned.
- Fails loudly if the dump comes out suspiciously small.

Schedule it (cron / managed-DB snapshot + this for logical backups), e.g. hourly:

```cron
0 * * * * cd /srv/smartride && ./scripts/db_backup.sh >> /var/log/smartride-backup.log 2>&1
```

### Restore

```bash
CONFIRM=yes ./scripts/db_restore.sh                       # newest dump
CONFIRM=yes ./scripts/db_restore.sh ./backups/smartride_20260612_101500.dump
```

- Requires `CONFIRM=yes` because `--clean --if-exists` drops and recreates objects.
- `--exit-on-error` so a broken dump fails instead of leaving a half-restored DB.

### Verified

A backup→restore drill was run on 2026-06-12: dumped the live DB, restored into a
fresh database, and confirmed every table's row count matched exactly
(users 31, drivers 15, patients 17, hospitals 5, rides 19), PostGIS extension
included. **A backup you have never restored is not a backup** — re-run this drill
on a schedule (e.g. monthly restore-to-scratch).

## Connection pooling (PgBouncer)

Postgres handles a limited number of connections; under real concurrency a pooler
prevents connection exhaustion. PgBouncer is provided as an opt-in service.

```bash
docker compose --profile pooling up -d pgbouncer
```

Then point the backend at it:

- `DATABASE_URL=postgresql+asyncpg://smartride:password@pgbouncer:6432/smartride`
- `DB_DISABLE_PREPARED_CACHE=true`

The flag is required: PgBouncer runs in **transaction** pooling mode, and asyncpg's
prepared-statement cache is session-scoped, so it must be disabled (the engine in
`app/core/database.py` reads this flag and sets `statement_cache_size=0`).

Defaults: `POOL_MODE=transaction`, `DEFAULT_POOL_SIZE=25`, `MAX_CLIENT_CONN=1000`.

## Staging environment

Run a staging stack that mirrors production before promoting releases:

- Separate `.env` with `DEBUG=false`, a real `SECRET_KEY`, explicit
  `ALLOWED_ORIGINS`, and staging Twilio/Firebase credentials.
- Its own database — **never** test against production data.
- Same compose file; override image tags / env per environment.
- Run migrations (`alembic upgrade head`) on deploy; the entrypoint already does.
- Smoke test after deploy: `/health` and `/ready` must both return 200.

## Release flow (recommended)

1. CI green on the branch (lint, tests, coverage floor, APK build).
2. Deploy to staging; run the smoke test + a manual booking→dispatch flow.
3. Back up production (`db_backup.sh`) immediately before promoting.
4. Promote; watch the Grafana dashboard + alerts (see `OBSERVABILITY.md`) for 5xx
   and dispatch-failure spikes.
5. Rollback path: restore the pre-deploy backup if a migration goes wrong.
