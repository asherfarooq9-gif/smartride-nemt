# Security Assessment — NEMT FYP Project

**Date:** 2026-10-24
**Scope:** Static source-code analysis only. No live traffic was sent to any
environment (local, staging, or deployed Render instance). All findings are
derived from reading `backend/`, `admin-dashboard/`, `docs/`, Dockerfiles,
CI workflows, and config files in this repository.
**Standards referenced:** OWASP Top 10 (2021), OWASP API Security Top 10
(2023), CWE, MITRE ATT&CK (where applicable to a static review).
**Authorization:** Repo owner requested this assessment of their own
application.

---

## 1. Executive Summary

This codebase is noticeably more hardened than a typical student/FYP project
against the attack classes that usually break apps like this: SQL injection
(none found — Pydantic + SQLAlchemy parameterized queries throughout, no raw
`request.json()` access anywhere), IDOR (ownership checks applied
consistently on every ID-based endpoint), JWT forgery (no `alg:none`, secret
loaded from env with a fail-fast boot guard), and wallet race conditions
(atomic SQL increments plus Postgres-enforced append-only ledger plus
unique-constraint idempotency — no double-spend path found).

The real findings are in three places: (1) **business-logic trust
assumptions** — the app validates *shape* (types, ranges, formats) but not
*plausibility* (fabricated GPS coordinates, free-text symptom descriptions
used to self-select emergency severity, a driver completing a ride
instantaneously); (2) **defense-in-depth gaps on the edges** — a handful of
endpoints missing dedicated rate limits, a confirmed fail-open path during
Redis outages, no SAST in CI; (3) **a compliance gap the team already
documented themselves** (`docs/PHI_COMPLIANCE_AUDIT.md`) around PHI
encryption-at-rest and audit trails.

No critical, immediately-exploitable vulnerability was found. The highest-
priority items are Medium severity and are listed first below.

---

## 2. Findings Table

| # | Finding | Category | Severity | Location |
|---|---|---|---|---|
| 1 | Token revocation / login-lockout fail open during Redis outage | CWE-613 (Insufficient Session Expiration) | **Medium** | `backend/app/core/redis_client.py:81-88` |
| 2 | Free-text `symptom_text` can self-select maximum dispatch severity | CWE-840 (Business Logic Errors) / OWASP API6 | **Medium** | `backend/app/services/emergency_dispatch.py:188-189` |
| 3 | No plausibility check on ride-status transition speed | CWE-840 | **Medium** | `backend/app/services/ride_service.py:259-292` |
| 4 | Unvalidated GPS coordinates feed fare calc and dispatch matching | CWE-20 (Improper Input Validation) | **Medium** | `backend/app/schemas/rides.py`, `backend/app/services/emergency_dispatch.py:265-291` |
| 5 | Scheduled ride creation has no idempotency / dedup guard | CWE-840 | **Low-Medium** | `backend/app/services/ride_service.py:137-153` |
| 6 | JWT weak-key validation only enforced when `DEBUG=False` | CWE-521 (Weak Credential Requirements) | **Medium** | `backend/app/core/config.py:84-95` |
| 7 | `/auth/switch-role` has no rate limit | CWE-307 (Improper Restriction of Excessive Auth Attempts) | **Low** | `backend/app/routers/auth.py:277` |
| 8 | Driver write endpoints (`/location`, `/status`) and wallet top-up rely only on global rate limit | CWE-307 | **Low** | `backend/app/routers/drivers.py` |
| 9 | Emergency-dispatch SMS/hospital fan-out unthrottled once triggered; best-effort failure logging only | CWE-754 (Improper Check for Unusual Conditions) | **Low** | `backend/app/services/emergency_dispatch.py:385-409` |
| 10 | WS per-user/per-IP connection caps are per-process only | CWE-770 (Allocation w/o Limits, multi-instance) | **Low** | `backend/app/routers/ws.py:7-9,38,60-70` |
| 11 | Idempotency-Key replay for emergency rides doesn't verify body matches original | CWE-840 | **Low** | `backend/app/routers/rides.py:107-120` |
| 12 | `/ready` leaks DB/Redis availability unauthenticated | CWE-200 (Information Exposure) | **Low** | `backend/main.py:266-292` |
| 13 | PHI stored plaintext at the application layer, relying on infra-level disk encryption only | CWE-311 (Missing Encryption of Sensitive Data) | **Medium** (compliance) | `schema.sql`, `docs/PHI_COMPLIANCE_AUDIT.md` |
| 14 | No SAST tool in CI (dependency/image/secret scanning only) | Process gap | **Low** | `.github/workflows/security.yml` |
| 15 | GitHub Actions pinned by version tag, not commit SHA | CWE-829 (Inclusion of Functionality from Untrusted Control Sphere) | **Info** | `.github/workflows/*.yml` |
| 16 | Admin-dashboard E2E seed credentials committed to repo | CWE-798 (Use of Hard-coded Credentials, test-scope) | **Info** | `admin-dashboard/e2e/*.ts` |
| 17 | Backend/triage Docker images are single-stage (build tools not stripped) | Hardening gap | **Info** | `backend/Dockerfile`, `ai-services/triage/Dockerfile` |

---

## 3. Detailed Findings

### #1 — Token revocation and login-lockout fail open on Redis outage

- **CWE-613** / OWASP API2:2023 (Broken Authentication)
- **Severity:** Medium
- **Location:** `backend/app/core/redis_client.py:81-88` (`is_token_blocked`), confirmed by the module's own docstring at lines 7-17.
- **Description:** `is_token_blocked` catches `RedisError`/`OSError`/timeout and returns `False` — i.e. "not revoked" — on any Redis failure, logging an error but not blocking the request. The same file documents that login-lockout counters also fail open (no lockout enforced) under the same condition. This is a deliberate, documented availability-over-security tradeoff, not an oversight.
- **Theoretical PoC (not executed):** If Redis becomes unreachable (network partition, redis container restart, OOM-killed), any previously logged-out or admin-revoked JWT remains fully valid until its own `exp` claim (default 60 minutes, `JWT_EXPIRE_MINUTES`). Simultaneously, login brute-force attempts are not rate-limited by the lockout mechanism during the same window (the separate `slowapi` rate limiter still applies per the fallback described in `ratelimit.py:38-51`, but the dedicated lockout does not).
- **Impact:** A revoked token (e.g. from a compromised device that was logged out) can still be used for up to 60 minutes if the attacker's request happens to land during a Redis outage. Bounded impact — capped by token TTL, not indefinite.
- **Likelihood:** Low — requires a Redis outage window coinciding with an attacker holding a specifically-revoked token. Not opportunistically exploitable by an outside attacker; more of an operational risk during incidents.
- **Remediation:** Either (a) accept as-is (it is a documented, reasoned availability tradeoff — many systems do this), or (b) if stricter posture is wanted, fail closed specifically for `is_token_blocked` (treat Redis-down as "blocked" rather than "not blocked") while keeping rate-limiting and login-lockout fail-open for availability, since blocking all auth on a cache outage is a bigger business risk for a transport-dispatch app with emergency rides. Shortening default `JWT_EXPIRE_MINUTES` tightens the exposure window regardless.

### #2 — Free-text symptom description can force maximum dispatch severity

- **CWE-840 (Business Logic Errors)** / OWASP API6:2023 (Unrestricted Access to Sensitive Business Flows)
- **Severity:** Medium
- **Location:** `backend/app/services/emergency_dispatch.py:188-189` (`detect_severity_override`/`FAIL_SAFE_SEVERITY`), `backend/app/schemas/rides.py:12-16` (`symptom_text` is the only clinical input field), dispatch ordering in `backend/app/services/dispatch_loop.py:153-178`.
- **Description:** Dispatch priority is `ORDER BY severity_level DESC, queued_at`. Severity comes from local keyword matching (`triage_keywords.py`) or an external triage call over the patient's own free-text `symptom_text`. There is no field the client can set directly for priority, but the text content itself is fully client-controlled and feeds a keyword-triggered fail-safe path that forces the highest severity (5).
- **Theoretical PoC (not executed):** A patient submits `POST /api/v1/rides/emergency` with `symptom_text` worded to trigger the fail-safe override keywords, receiving severity 5 and jumping the dispatch queue ahead of patients whose triage classification came back lower, independent of actual medical urgency. Bounded by the existing `5/minute` rate limit on ride creation and the one-active-emergency-per-patient DB constraint.
- **Impact:** Queue-jumping in a system whose entire purpose is prioritizing genuinely urgent medical transport — this is a safety-relevant business-logic gap, not just a technical one.
- **Likelihood:** Medium — requires knowing or guessing the fail-safe keyword set, but that set likely exists precisely to catch severe-sounding language, so crafting a qualifying phrase is plausible without special access.
- **Remediation:** Treat the keyword fail-safe as a *lower bound/alert* (flag for human triage review) rather than an automatic top-priority grant; log and rate-limit fail-safe triggers per patient separately from normal ride creation; consider requiring hospital/triage-service confirmation before fail-safe severity affects queue order, with the keyword match only accelerating human review time.

### #3 — No plausibility check on ride-status transition speed

- **CWE-840**
- **Severity:** Medium
- **Location:** `backend/app/services/ride_service.py:259-292` (`_apply_driver_transition`, `DRIVER_TRANSITIONS`)
- **Description:** The state machine enforces strict ordering (`pending → driver_assigned → driver_en_route → patient_picked_up → arrived_at_hospital → completed`) but no timing, GPS-proximity, or minimum-duration check. `final_fare_pkr` and driver commission are computed only on reaching `completed`.
- **Theoretical PoC (not executed):** An authenticated driver assigned to a ride calls the status-update endpoint through all five transitions within seconds of each other, with no requirement that GPS location data corroborate actual movement between pickup and hospital.
- **Impact:** A driver could claim and "complete" rides without performing real transport, triggering fare/commission calculation on fabricated service. Combined with finding #2, a colluding patient+driver pair could fabricate an urgent, instantly-completed ride.
- **Likelihood:** Medium — requires an authenticated driver account, which is a real barrier, but no technical skill beyond calling the existing API in sequence.
- **Remediation:** Add server-side minimum dwell time between transitions and/or require the driver's live GPS (already streamed over the tracking WebSocket) to be within a reasonable radius of the ride's pickup/hospital coordinates at the corresponding transition before accepting it.

### #4 — Unvalidated GPS coordinates feed fare and dispatch matching

- **CWE-20**
- **Severity:** Medium
- **Location:** `backend/app/schemas/rides.py` (`pickup_lat`/`pickup_lng`, range-bounded only: `-90..90`/`-180..180`), fare calc in `backend/app/services/ride_service.py` (`ride_fare`), dispatch matching in `emergency_dispatch.py:265-291`.
- **Description:** There is no "price" field anywhere in the schema — fare is always server-computed via haversine distance from the ride's *stored* pickup coordinates to the matched hospital. However those stored coordinates come directly from client input with only numeric-range validation, no plausibility check (e.g., consistency with IP geolocation, device GPS accuracy, or city bounds).
- **Theoretical PoC (not executed):** A patient submits coordinates placing pickup very close to a cheap/nearby hospital match (or, conversely, exaggerating distance) to manipulate the computed fare, or submits coordinates that cause a mismatch between claimed and actual location for dispatch purposes.
- **Impact:** Fare manipulation and/or driver dispatch to the wrong real-world location — a minor financial fraud vector and a potential real-world safety issue (driver sent to a fabricated location while patient is elsewhere).
- **Likelihood:** Low-Medium — requires intent to defraud and knowledge that coordinates are trusted; most legitimate app usage would send accurate device GPS.
- **Remediation:** Cross-check submitted coordinates against a reasonable bound (e.g., known service area polygon), and/or compare against IP-based geolocation for an anomaly flag, not a hard block — flag large mismatches for review rather than silently trusting them.

### #5 — Scheduled ride creation has no idempotency guard

- **CWE-840**
- **Severity:** Low-Medium
- **Location:** `backend/app/services/ride_service.py:137-153` (`create_scheduled_ride`), contrast with emergency ride creation's `uq_rides_active_emergency_per_patient` partial unique index (`models.py:388-398`) and `Idempotency-Key` support (`rides.py:107-120`).
- **Description:** Emergency rides are protected from duplicate creation by both a DB unique index and an idempotency-key replay cache. Scheduled rides have neither.
- **Theoretical PoC (not executed):** A double-tap on "schedule ride" in the mobile app, or a client-side retry after a slow/timed-out response, creates two independent scheduled-ride rows with no deduplication.
- **Impact:** Duplicate scheduled rides — operational/billing confusion, not a security breach, but a real functional bug with financial-adjacent consequences (could result in two drivers dispatched, or double charges if scheduled rides are ever billed before completion).
- **Likelihood:** High for occurrence (any network hiccup or impatient double-tap triggers it), Low for malicious exploitation value.
- **Remediation:** Add the same `Idempotency-Key` pattern already built for emergency rides and wallet top-ups to the scheduled-ride endpoint; consider a short per-patient "no duplicate pending/scheduled ride within N minutes" constraint analogous to the emergency one.

### #6 — JWT weak-key validation gated behind `DEBUG=False`

- **CWE-521**
- **Severity:** Medium
- **Location:** `backend/app/core/config.py:84-95` (`validate_production_secrets`), `backend/main.py:66-71`
- **Description:** The app refuses to boot with the known default `SECRET_KEY` regardless of `DEBUG`, but the additional length/charset strength checks on a *custom* key are only run when `DEBUG=False`. A deployment accidentally left with `DEBUG=True` (or `ENVIRONMENT` misconfigured) would accept a short/weak custom signing key.
- **Theoretical PoC (not executed):** Deploy with `DEBUG=True` and `SECRET_KEY=abc123` (not the known default, so the default-value check passes, but weak). JWTs are now signed with a brute-forceable key.
- **Impact:** If combined with a `DEBUG=True` production misconfiguration (which also relaxes CORS to wildcard per `config.py:93-97` and enables `/docs`), a weak signing key could allow JWT forgery — full authentication bypass.
- **Likelihood:** Low — requires a specific misconfiguration (debug mode left on in a real deployment), which is itself the primary risk; the weak-key issue is secondary to that misconfiguration.
- **Remediation:** Run the length/charset strength check on `SECRET_KEY` unconditionally (not gated by `DEBUG`), since a weak key is a bad idea in dev too and costs nothing to enforce always.

### #7-#10 — Rate-limiting gaps on secondary endpoints

- **CWE-307**
- **Severity:** Low (each)
- **Locations:** `/auth/switch-role` (`auth.py:277`), driver `/location`+`/status` and wallet top-up (`drivers.py`), emergency-dispatch notification fan-out (`emergency_dispatch.py:385-409`), WS connection caps being per-process (`ws.py:7-9,38,60-70`).
- **Description:** These endpoints fall back to the global `200/minute` limiter rather than a dedicated tighter limit, or (for WS caps and the notification fan-out) aren't covered by the HTTP rate limiter at all. None of these were found to enable a severe attack on their own — the critical paths (login, register, emergency-ride creation, role-add) already have dedicated limits.
- **Impact:** Token churn on `/switch-role` could grow the Redis blocklist; unthrottled driver-location writes add load; multi-instance deploys don't share WS connection-cap state, so the stated per-user cap of 5 sockets is actually `5 × worker_count`.
- **Remediation:** Add dedicated `@limiter.limit(...)` decorators to `/switch-role` and `/location`; move WS connection counting to Redis (shared across processes) if horizontal scaling beyond one worker is planned; add a retry/backoff cap to the dispatch notification fan-out independent of the create-endpoint's rate limit.

### #11 — Idempotency-Key replay doesn't verify request body

- **CWE-840**
- **Severity:** Low
- **Location:** `backend/app/routers/rides.py:107-120` vs. the stricter pattern at `backend/app/routers/drivers.py:270-274` (wallet top-up checks `previous.amount == amount` before returning a cached result).
- **Description:** Replaying an emergency-ride creation with the same `Idempotency-Key` but a *different* body (e.g., updated `symptom_text` describing worsening symptoms) silently returns the original ride, discarding the new data.
- **Impact:** Not a security hole — can't be used to escalate privilege or fraud — but a real safety-relevant surprise: a legitimate retry with updated critical information (worsening condition) is silently dropped.
- **Remediation:** Apply the same body-match check used for wallet top-up: if the replayed key's stored body doesn't match the incoming body, reject with a 409 rather than silently returning the stale ride.

### #12 — `/ready` leaks infrastructure status unauthenticated

- **CWE-200**
- **Severity:** Low
- **Location:** `backend/main.py:266-292`
- **Description:** The readiness probe reports DB/Redis connectivity without authentication, which is normal for container orchestration health checks but does hand an unauthenticated caller a small amount of infra reconnaissance (whether Redis is currently reachable, for example).
- **Remediation:** Low priority — restrict at the network/ingress layer to internal health-check traffic only if this matters for the threat model; functionally this is a standard k8s/Render pattern.

### #13 — PHI stored plaintext at the application layer

- **CWE-311**
- **Severity:** Medium (compliance-relevant)
- **Location:** `schema.sql` (`patients.full_name`, `patients.date_of_birth`, `patients.mobility_needs`, `patients.emergency_contact_*`, `rides.symptom_text`, `triage_events.symptom_text`, `drivers.license_no`, `drivers.vehicle_plate`); self-documented in `docs/PHI_COMPLIANCE_AUDIT.md`.
- **Description:** These columns rely entirely on hosting-provider disk encryption, with no application-level column encryption. The project's own compliance audit already lists three open gaps: no data-retention/erasure policy, no PHI-access audit trail (no record of who viewed `symptom_text`/ride detail), and no regression test locking in the earlier fix that scoped `symptom_text` visibility away from drivers.
- **Impact:** A database-level compromise (backup theft, misconfigured access, insider threat) exposes PHI in cleartext. This is a defense-in-depth gap, not an exploitable application vulnerability by itself.
- **Remediation:** This is already tracked by the team in `docs/PHI_COMPLIANCE_AUDIT.md` — treat the three listed open items (retention/erasure, access audit trail, regression test) as the existing remediation backlog rather than duplicating new work here. Application-level encryption for the highest-sensitivity fields (`symptom_text` especially) would be the next step if resourcing allows.

### #14-#17 — Process and supply-chain hygiene

- **Severity:** Low/Info
- `.github/workflows/security.yml` runs `pip-audit`, `npm audit`, Trivy image scanning, and Gitleaks secret scanning on a schedule and on push/PR — good coverage for dependency/image/secret classes. No SAST tool (CodeQL/Semgrep/Bandit) is present for catching injection/XSS/auth-bypass *patterns* in code, which is a reasonable next addition given the CI already has the scanning habit.
- GitHub Actions are pinned by version tag (`@v4`, `@0.28.0`) rather than commit SHA — standard practice, but technically mutable if a tag were ever moved upstream.
- `admin-dashboard/e2e/api.ts` and `global-setup.ts` contain seed credentials (`admin123`, `patient123`, `driver1234`) for Playwright E2E tests against an ephemeral CI database spun up by `scripts/e2e_backend.py`. Not a real secret, but worth a standing reminder: never point this E2E suite at a shared/staging database reachable from outside CI.
- `backend/Dockerfile` and `ai-services/triage/Dockerfile` are single-stage builds (unlike `admin-dashboard/Dockerfile`'s proper 3-stage build), so pip/build tooling remains in the final image. Both already run as non-root (`useradd --uid 10001 app`). Multi-stage would reduce final image size and attack surface slightly; not urgent.

---

## 4. Attack Chains

1. **Fabricated-urgency fast-completion fraud:** A patient crafts `symptom_text` to trigger the fail-safe severity override (#2), jumping the dispatch queue. If the assigned driver is complicit (or is the same person via a dual-role account), they race through all ride-status transitions (#3) with no GPS/time plausibility check, triggering fare and commission calculation on a largely fabricated emergency transport event. Each individual step is a Medium finding; chained, this is the most realistic fraud path in the system. Mitigating either #2 or #3 breaks the chain.

2. **Location-spoofing fare/dispatch manipulation:** Unvalidated GPS (#4) feeds both the hospital-matching distance calculation and the final fare formula. A patient submitting fabricated coordinates could cheapen their fare or cause a driver to be dispatched to the wrong real-world location. Lower severity than chain 1 since it requires no collusion but also yields smaller gain.

No chain in this review reached full account takeover, data exfiltration at scale, or remote code execution — the hardened auth/IDOR/injection surface meant no entry point existed to start a more severe chain.

---

## 5. Remediation Roadmap

**Quick wins (hours, no architecture change):**
- Add body-match check to emergency-ride idempotency replay (#11) — mirror the existing wallet top-up pattern.
- Add dedicated rate limit to `/auth/switch-role` (#7).
- Run JWT weak-key strength check unconditionally, not gated by `DEBUG` (#6).
- Add `Idempotency-Key` support to scheduled-ride creation (#5) — copy the emergency-ride pattern.

**Near-term (days):**
- Add minimum-dwell-time and/or GPS-proximity check between ride-status transitions (#3).
- Add dedicated rate limits to driver `/location`/`/status` and a retry cap to the emergency-notification fan-out (#8, #9).
- Move WS per-user connection-cap counters to Redis for correctness under multi-worker deployment (#10).
- Add a SAST tool (CodeQL or Semgrep) to `.github/workflows/security.yml`, alongside the existing dependency/image/secret scanning (#14).

**Strategic (weeks, needs product input):**
- Decide and implement a policy for the fail-safe severity override (#2) — likely: flag for human triage confirmation rather than fully automatic top-priority dispatch.
- Add plausibility bounds on submitted GPS coordinates relative to service area (#4).
- Work through the three open items already tracked in `docs/PHI_COMPLIANCE_AUDIT.md` — retention/erasure policy, PHI-access audit trail, regression test for the `symptom_text` driver-visibility fix (#13).
- Decide whether to fail closed on `is_token_blocked` specifically during Redis outages, accepting the availability tradeoff this introduces for an emergency-dispatch system (#1) — current fail-open behavior is a defensible, documented choice, not a clear bug.

---

## 6. Security Scorecard

| Category | Rating | Notes |
|---|---|---|
| Authentication | Strong | Bcrypt hashing, timing-safe login, phone+IP lockout, JWT with revocation. Deductions for Redis fail-open (#1) and DEBUG-gated key strength check (#6). |
| Authorization / IDOR | Strong | Ownership checks (`_authorize_ride_access`, `_may_watch`) applied consistently everywhere an ID is accepted. No gap found. |
| Injection | Strong | Parameterized queries (SQLAlchemy) throughout, Pydantic validation on every input, no raw body/dict access found anywhere in `app/`. |
| Business logic | Moderate | The category carrying most of this report's findings (#2-#5) — the app validates shape well but not real-world plausibility. |
| Rate limiting | Moderate | Strong on the highest-risk endpoints (login, register, emergency create); several secondary endpoints fall back to a generous global default. |
| Data protection / PHI | Moderate | No app-level secrets found hardcoded; PHI-at-rest and audit-trail gaps are real but already self-tracked by the team. |
| Dependencies / CI | Strong | pip-audit, npm audit, Trivy, Gitleaks all running on schedule; missing only a SAST layer. |
| Client-side (WS/admin) | Strong | WebSocket auth is comparatively well-hardened (timeout, per-IP caps, mid-stream expiry recheck); only gap is per-process-only counters under multi-worker scaling. |

---

## 7. Remediation Status

Updated after the fixes on branch `security/assessment-hardening`.

**Fixed**

| # | Fix |
|---|---|
| 3 | `RIDE_MIN_TRANSITION_SECONDS` rejects `arrived_at_hospital` / `completed` that follow `pickup_at` / `arrived_at` too quickly. Off by default (dev, tests); set to 15 in `render.yaml` and `docker-compose.prod.yml`. |
| 4 | `SERVICE_AREA_BBOX` rejects emergency and scheduled pickups outside the box (422). Off by default (the Android emulator reports California); set to Pakistan in the production configs. |
| 5 | Scheduled-ride creation accepts `Idempotency-Key`; a replay returns the first ride with 200. |
| 6 | Fixed at the root: `ENVIRONMENT=production` with `DEBUG=true` now refuses to start (DEBUG is what skipped the key-strength and CORS checks). Short keys stay allowed in a development DEBUG run, which an existing test pins as intentional. |
| 7, 8 | Dedicated limits on `/auth/switch-role` (20/min), driver `/status` (30/min) and `/location` (60/min). Wallet top-up is admin-only and left on the global limit. |
| 11 | Replaying an `Idempotency-Key` with a different body now returns 409 for both emergency and scheduled rides. |
| 14 | Bandit job added to `.github/workflows/security.yml` (medium+ severity and confidence; the current code scans clean). |

**Deliberately not changed**

| # | Why |
|---|---|
| 1 | Failing open on a Redis outage is a documented availability choice for an emergency-dispatch system. Revisit only if the team wants fail-closed revocation. |
| 2 | The keyword severity override is a clinical safety decision ("over-triage costs a faster ambulance, under-triage costs a life", `emergency_dispatch.py`). Changing it needs clinical sign-off, not a code-only fix. |
| 9, 10 | Need design work: an outbox/retry policy for notifications and Redis-backed WebSocket counters. |
| 12 | Standard orchestration readiness probe; restrict at the ingress if it matters. |
| 13 | Already tracked in `docs/PHI_COMPLIANCE_AUDIT.md`. |
| 15–17 | Hygiene items: SHA pinning needs resolved commit SHAs (best done with Dependabot), E2E seed credentials are test-only, multi-stage backend image is an optimisation. |

---

## 8. Notes on Methodology

This was a **static, read-only code review** — no requests were sent to any
running instance of the application, local or deployed. Findings describing
"theoretical PoC" are derived from reading the code paths involved and
describing what a request would need to look like to trigger the behavior;
they were not executed. If live verification is wanted later, it should be
run only against a local `docker-compose` dev stack, never against the
Render deployment or any shared database.
