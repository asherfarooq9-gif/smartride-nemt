# SmartRide runbook

Everything an operator needs on day one. Backups, pooling and staging are in
[OPERATIONS.md](OPERATIONS.md); dashboards and alerts are in
[OBSERVABILITY.md](OBSERVABILITY.md).

## What runs

| Service | Port | Needs | Notes |
|---|---|---|---|
| `backend` (FastAPI) | 8000 | Postgres, Redis | Runs `alembic upgrade head` on every start, then serves. Also runs the dispatch retry loop (one asyncio task per instance; safe to run several). |
| `triage` | 8001 | nothing | Rule-based. If it is down, the backend falls back to keyword rules, so dispatch still works. |
| `admin_dashboard` (Next.js) | 3000 | `backend` | The API URL is baked in at build time (`NEXT_PUBLIC_API_URL`). |
| Postgres 16 + PostGIS, Redis 7 | internal | | Redis holds token revocations, login lockouts, rate-limit counters, cache. |
| Prometheus, Grafana | 9090, 3001 | | `/metrics` needs `METRICS_TOKEN`. |

## Deploy

```bash
cp .env.example .env            # then fill in every value; never commit it
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
docker compose exec -e ADMIN_PASSWORD='<strong password>' backend python seed.py
```

`docker-compose.prod.yml` refuses to start unless these are set:
`POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `SECRET_KEY` (32+ random bytes),
`ALLOWED_ORIGINS` (JSON list, e.g. `["https://admin.example.com"]`),
`METRICS_TOKEN`, `NEXT_PUBLIC_API_URL`, `GRAFANA_USER`, `GRAFANA_PASSWORD`.

Put TLS in front of `backend` and `admin_dashboard` (nginx, Caddy or a cloud load
balancer) and set `FORWARDED_ALLOW_IPS` to the proxy's address so rate limits see
real client IPs. Production ports are bound to `127.0.0.1` for that reason.

Never set `FORWARDED_ALLOW_IPS` to `*`. uvicorn then trusts the left-most
`X-Forwarded-For` entry, which the client controls, and the IP rate limits and login
lockout can be bypassed. On Render it is set to the private ranges in `render.yaml`;
after a deploy, send `curl -H 'X-Forwarded-For: 1.2.3.4'` to `/auth/login` and check the
logged client IP is yours, not `1.2.3.4`.

Wallet top-ups (`POST /drivers/{id}/wallet/topup`) require an `Idempotency-Key` header;
reuse the same key when retrying so the driver is credited once.

Optional integrations, all of which degrade gracefully when unset: `TWILIO_*`
(SMS to family and hospitals), `FIREBASE_PROJECT_ID` + credentials file (push),
`SENTRY_DSN`.

## Release and rollback

1. Merge to `main` only when CI is green (backend, Flutter, triage, admin build, Playwright).
2. Tag `vX.Y.Z` to build the signed Android APK. The workflow refuses to run without
   the signing secrets (`KEYSTORE_*`, `KEY_*`, `API_BASE_URL`).
3. Roll the backend back by redeploying the previous release (on Render, roll back to
   the previous deploy). Do this first; it is almost always enough.
4. Database: prefer rolling forward. Every migration is additive for the previous
   release, so release N-1 runs on schema N:
   - `0006` converts `wallet_balance_pkr` to `NUMERIC(12,2)` and adds the
     `wallet_transactions` ledger.
   - `0007` adds ledger guards, a unique idempotency key and indexes. **Its downgrade
     refuses to run** once the ledger holds idempotency keys, admin ids or payment
     methods, or once rides carry `symptom_text`. That is deliberate: it would destroy
     audit data. Do not force it.
   - `0008` **dropped** `hospital_alerts` and `family_notifications`. They were never
     written to, so nothing is lost. Its downgrade recreates them empty.
   - `0009` adds `users.token_version`. The previous release ignores it, and tokens
     issued without a version count as 0, so nothing is signed out by the deploy.

   If you must go back, take a backup first (`scripts/db_backup.sh`), then step down
   one revision at a time (`alembic downgrade 0008`, and so on) and stop at the first
   refusal. A downgrade past `0006` is never needed to undo a bad release.
5. The backend runs `alembic upgrade head` on every start. With more than one
   instance, start one first and wait for it to be healthy before scaling out.

## Incidents

**A patient says nobody came.** Check the ride: `GET /api/v1/rides/{id}/detail` as admin.
`pending` older than 30 s means no driver was available; the dispatch loop retries every
15 s and cancels after `DISPATCH_MAX_AGE_SECONDS` (15 min) with the reason
"No driver available". Tell the patient to call 1122 while you check
`smartride_dispatch_failures_total{reason=...}` in Grafana.

**Dispatch seems stuck.** Look for `dispatch loop pass failed` in the backend logs. The
loop restarts itself each interval; a repeating error is almost always the database.
Restarting the backend is safe.

**A user is locked out.** Five wrong passwords from one address lock that address for
15 minutes for that phone number. 25 wrong passwords from any addresses also lock
addresses that have never logged in to that account; an address that has logged in
within the last 30 days is exempt from that second limit, so the owner is not locked
out by someone else's guessing. Clear it early with
`redis-cli --scan --pattern 'login_fail:*+92300xxxxxxx*' | xargs redis-cli DEL`.

**Sign a user out everywhere** (a stolen phone, a leaked token). The user can call
`POST /api/v1/auth/logout-all`. Support can do the same in SQL:
`UPDATE users SET token_version = token_version + 1 WHERE phone = '+92300xxxxxxx';`
Every token issued before that stops working immediately.

**Redis is down.** Every authenticated request fails (token revocation cannot be
checked) and `/ready` reports `redis: false`. Restore Redis; nothing else needs a restart.

**Suspected leaked token.** Revoke one user's sessions by disabling the account
(`users.is_active = false`; effective immediately). To end every session, rotate
`SECRET_KEY` and restart: all users must sign in again.

**Secrets rotation.** `SECRET_KEY` (see above), `POSTGRES_PASSWORD` (change in Postgres
and in the environment, restart `backend`), `METRICS_TOKEN` (also update the Prometheus
scrape config), Twilio and Firebase credentials in their consoles.


## Business rules the code enforces

- A driver may accept a ride only while **available** (not offline, not already on a ride), and never their own ride.
- Dispatch only considers drivers within `DRIVER_SEARCH_RADIUS_KM` (default 50) of the pickup.
- A patient may cancel until pickup; a driver cancelling before pickup puts the ride back in the queue and goes offline.
- Commission is `COMMISSION_RATE` (10%) of the fare and is charged once per ride; fares are `FARE_BASE_PKR` + `FARE_PER_KM_PKR` per km (pickup to hospital).

## Known gaps and what is not verified

Not built: the hospital and family SMS and FHIR sends leave no audit record; drivers cannot
top up their own wallet; the driver and patient screens are separate code (no shared screens).

Written but never run (needs GitHub Actions or real devices): the release workflow's
signing step, the CI `e2e`, `admin-dashboard`, `triage-tests` and security jobs
(including Trivy), the Flutter `integration_test` flows (none exist), and anything on a
physical phone (GPS in the background, push, calling).


## Before the first real patient (owner's checklist)

Things code cannot do for you:

- [ ] Production domain, TLS certificate, DNS.
- [ ] Firebase project: `google-services.json` for Android, `GoogleService-Info.plist`
      for iOS, service-account file for the backend (`FIREBASE_CREDENTIALS_PATH`).
- [ ] Twilio account and sender number (`TWILIO_*`).
- [ ] Android upload keystore and Play Console / App Store Connect accounts.
- [ ] Privacy policy, terms of service, and a review of `docs/PHI_COMPLIANCE_AUDIT.md`
      against the rules that apply where you operate (health data).
- [ ] Hospital agreements for the pre-alert (SMS or FHIR endpoints) and a driver
      onboarding / verification process (`PATCH /drivers/{id}/verify`).
- [ ] An external penetration test and a load test against the real topology
      (`backend/loadtest.py`, `scripts/soak_test.py`).
- [ ] A payment provider if drivers should top up themselves (today an admin credits
      wallets by hand; fares and commission are recorded in the ledger).
- [ ] Test on real phones: GPS in the background, push notifications, calling and SMS.
