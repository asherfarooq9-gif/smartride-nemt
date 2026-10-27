# Implementation Plan: Audit remediation (2026-10-25)

## Overview

Fix everything in `docs/AUDIT_2026-10-25.md` that code can fix, in small tested slices, one commit per task. A1, A2, A3 and B1 are already done (commits on `fix/audit-a1-a3-b1`). The Flutter, triage/CI and dashboard-code audits died on a session limit and are Phase 5; their findings get appended to `tasks/todo.md` once they report.

Tasks are tracked in `tasks/todo.md` (default target).

## Architecture decisions

- **Test first, one commit per task.** Red test, minimal fix, `ruff check`, `ruff format --check`, focused tests, commit. Full suite at each checkpoint.
- **Migrations are additive** (expand/contract). The only schema changes are a nullable column and indexes. No destructive step in one release.
- **Safety over convenience on the emergency path.** When a notification or lookup fails, the ride keeps going and the failure is logged and counted. Nothing blocks a patient.
- **Defaults I chose where the audit left a decision open** (change them if wrong):
  - C2: a driver cannot cancel after pickup. They get a 409 telling them to call dispatch; an admin can still cancel.
  - B2: the per-phone ceiling skips addresses that have already logged in to that account; the per-(phone, address) streak still applies to them. (The audit's "let a correct password through behind a delay" would have weakened brute-force protection.)
  - B3: tokens carry a `token_version`; changing it logs a user out everywhere. Refresh stays fail-open when Redis cannot record the revocation (matching the blocklist, and a patient must not be signed out mid-emergency by a Redis blip); logout-all is the remedy for a stolen chain. The audit asked for fail-closed; this is a deliberate departure.
  - B5: drivers keep ride access only while it is active; after completion the patient phone and mobility needs are masked.
  - B4 (admin token in `localStorage`) is a cross-cutting rewrite to httpOnly cookies. It is its own phase at the end, and the admin TTL is shortened first.

## Phases

1. **Backend safety and money (T1 to T9)**. Small, independent, high value.
2. **Operations (T10 to T17)**. Config, probes, alerts, release gating.
3. **Test gaps (T18 to T21)**. Notifications, ride service, dispatch edge cases, export and idempotency.
4. **Performance (T22 to T26)**. Search indexes, summary cache, polling, dashboard rendering.
5. **Pending audits (T27 to T29)**. Flutter, triage/CI/Docker, dashboard code.
6. **Admin session hardening (T30)**.

Checkpoint after each phase: full backend suite green, coverage at least 60%, `ruff` clean, `docker compose config` valid, dashboard lint/typecheck/build when touched.

## Owner actions (not code, cannot be done by me)

Domain and TLS, Firebase project and credentials file, Twilio account and sender, Android release keystore, privacy policy and PHI review, hospital agreements, third-party penetration test, load test sign-off, real-phone testing, paid hosting plan decision, Alertmanager receiver (who gets paged, on what channel), and the JazzCash/EasyPaisa/bank account drivers should pay into (the top-up instructions tell them to pay and email a receipt but cannot name an account until you supply one). The 'Card' payment option on the top-up screen is not backed by anything and should be removed or built. Confirm the CI jobs listed as "never run" are green on `main`.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Token version column needs a migration on a live DB | Med | Nullable column with default 0, additive, covered by `test_migrations.py` |
| Cancel/requeue notifications add external calls to the request path | Med | Fire after commit, failures logged and counted, never raised |
| Dispatch loop concurrency changes ordering under load | High | Keep severity order, bounded semaphore, race tests in `test_dispatch_races.py` |
| Changing health probes breaks the Render/Docker healthchecks | Med | Keep `/health` as liveness, add readiness, update manifests and tests together |
| B1 still needs a live check on Render | Med | Owner runs the `curl` check in `docs/RUNBOOK.md` after deploy |
| Another session limit hit mid-phase | Low | Commit per task, plan file records progress |

## Open questions

- Who receives alerts (channel and on-call person)? Needed before T14 is useful.
- Is a paid Render plan approved? T13 only changes the manifest and docs.
- Confirm the four defaults above.
