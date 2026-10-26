# Task list: Audit remediation

Done before this plan: A1, A2, A3, B1 (see `git log fix/audit-a1-a3-b1`).
Each task: red test, fix, ruff, focused tests, commit. Size in brackets.

## Phase 1: Backend safety and money

- [x] **T1 (S)** C2: block a driver cancelling after pickup. AC: cancel from `patient_picked_up` or `arrived_at_hospital` returns 409 with a "contact dispatch" message; admin cancel still works; earlier states unchanged. Files: `ride_service.py`, `tests/test_ride_lifecycle.py`.
- [x] **T2 (M)** C1: notify on cancel and requeue. AC: patient or admin cancel pushes the driver and alerts the previously alerted hospital before `hospital_id` is cleared; requeue does the same; failures are logged and counted, never raised. Files: `ride_service.py`, `dispatch_loop.py`, `notifications.py`, tests.
- [x] **T3 (S)** C3: SMS fallback for the "call 1122" expiry. AC: when the push is not delivered, the patient (or emergency contact) gets an SMS; log says what actually reached them. Files: `dispatch_loop.py`, `notifications.py`, tests.
- [x] **T4 (S)** B2: guessing from many addresses must not lock the owner out. AC: the per-phone ceiling skips addresses that already logged in to the account (30 days); unknown addresses stay locked; the per-(phone, address) streak still applies. Files: `redis_client.py`, `routers/auth.py`, `tests/security`.
- [x] **T5 (M)** B3: per-user token invalidation. AC: nullable `users.token_version` (migration, additive); tokens carry it; mismatch is 401; change-password and logout-everywhere bump it; refresh fails when the revoke cannot be recorded. Files: `models.py`, migration, `security.py`, `routers/auth.py`, tests.
- [x] **T6 (S)** B5: mask patient phone and mobility needs for drivers once a ride is completed or cancelled. Files: `routers/rides.py`, tests.
- [x] **T7 (M)** C5, C6: WebSocket ownership re-check, fewer DB queries per GPS frame, and `_release_driver` must not mark an offline driver available. Files: `ws.py`, `ride_service.py`, tests.
- [x] **T8 (M)** C4: dispatch loop runs rides concurrently under a small semaphore in severity order; fix the lock docstring. Files: `dispatch_loop.py`, `tests/test_dispatch_races.py`.
- [x] **T9 (S)** Low items: WebSocket revocation re-checked on a timer, `accept_ride` offered-to check, `render.yaml` Twilio vars `sync: false`.

### Checkpoint 1
- [ ] Full backend suite green, coverage at least 60%, ruff clean.

## Phase 2: Operations

- [x] **T10 (S)** D7: `/ready` used by orchestrator probes; `/health` stays liveness. Update `render.yaml`, Dockerfile healthcheck, compose, tests.
- [x] **T11 (S)** D4: advisory lock around `alembic upgrade head` in `entrypoint.sh`/`alembic/env.py`. Test: two concurrent upgrades do not race.
- [x] **T12 (S)** D3: rewrite the RUNBOOK rollback section (migrations 0007/0008, backup first, roll forward preferred).
- [x] **T13 (S)** D5: the paid-plan decision is the owner's; `render.yaml` now says plainly that `free` is pilot-only and why, and documents the no-triage fallback.
- [x] **T14 (M)** D1: Prometheus alert rules for DB/Redis down, stuck dispatch loop, aged pending rides, failed SMS/FHIR/push (add the metrics), ledger mismatch; add an Alertmanager config with a placeholder receiver. Receiver is a placeholder until the owner picks who is paged.
- [x] **T15 (S)** D2: `release.yml` waits for CI on the tagged commit (`require-green-ci`). Dropped: a backend image build/push job, because Render builds from the repo and no registry has been chosen (owner decision).
- [x] **T16 (S)** D6: prod compose mount for `FIREBASE_CREDENTIALS_PATH`; log a warning at startup when push is configured but the file is missing.
- [x] **T17 (S)** Document every `config.py` variable in `.env.example`.

### Checkpoint 2
- [ ] `docker compose config` valid for both files; backend suite green.

## Phase 3: Test gaps

- [ ] **T18 (M)** `notifications.py`: push, FHIR bundle, FHIR timeout/redirect/5xx, fallback.
- [ ] **T19 (M)** `ride_service.py`: illegal transitions, commission once under retry, refund on cancel, low wallet.
- [ ] **T20 (M)** `emergency_dispatch.py`: garbage triage output, hospital alert fails after assignment.
- [ ] **T21 (S)** `ride_export.py`, `idempotency.py`, `patient_service.py`, `hospital_service.py` ownership and PHI scope.

## Phase 4: Performance

- [ ] **T22 (S)** Trigram (GIN `gin_trgm_ops`) indexes for the three `ilike` searches (additive migration).
- [ ] **T23 (S)** Cache `/analytics/summary` for 15s in Redis.
- [x] **T24 (S)** Dashboard: pause polling when the tab is hidden.
- [x] **T25 (S)** Dashboard: dynamic import for Recharts; match skeleton to real layout (CLS).
- [ ] **T26 (M)** Dashboard: server-render the shell instead of a blank auth gate (measure first with Lighthouse).

### Checkpoint 3
- [ ] Backend suite green; dashboard lint, typecheck, build, Playwright green.

## Phase 5: Pending audits (append findings, then triage)

- [ ] **T27** Flutter app audit, then fix (driver money screens, dispatch UI, docs/code mismatch on top-up).
- [ ] **T28** Triage, CI, Docker audit, then fix.
- [ ] **T29** Dashboard code audit, then fix (the top-up UI must send `Idempotency-Key` if it exists).

## Phase 6

- [ ] **T30 (L, split first)** B4: admin session in an httpOnly cookie, shorter admin TTL, MFA decision.
