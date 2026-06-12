# SmartRide NEMT — FYP Defense Preparation

One-page architecture summary plus the questions a supervisor or external
examiner is most likely to ask, with answers grounded in the actual code.

---

## 1. What the system is

**SmartRide** is an AI-assisted non-emergency/emergency medical transport
platform for Pakistan (Islamabad/Rawalpindi pilot). A patient requests a ride
(emergency or scheduled), the system triages symptoms, matches a hospital,
dispatches the nearest verified driver, and the patient tracks the ambulance
live on a map. Family can be notified by SMS.

## 2. Architecture at a glance

```
┌─────────────────────────┐        ┌──────────────────────────────┐
│  Flutter app (1 APK)    │  REST  │  FastAPI backend (Python)    │
│  • Patient portal (blue)│◄──────►│  • JWT multi-role auth       │
│  • Driver portal (teal) │  WS    │  • Ride lifecycle + dispatch │
│  Riverpod + GoRouter    │◄──────►│  • WebSocket GPS relay       │
└─────────────────────────┘        │  • Rate limiting (slowapi)   │
┌─────────────────────────┐        ├──────────────────────────────┤
│  Admin dashboard (web)  │◄──────►│  PostgreSQL  │  Redis        │
└─────────────────────────┘        │  (SQLAlchemy │  (pub/sub +   │
┌─────────────────────────┐        │   async +    │   JWT block-  │
│  AI services            │◄──────►│   Alembic)   │   list)       │
│  • Symptom triage       │        └──────────────────────────────┘
│  • Hospital matching    │         Push: Firebase FCM
└─────────────────────────┘         SMS: Twilio   Crashes: Crashlytics
```

**Tech choices:** FastAPI (async Python web framework), PostgreSQL,
Redis, Flutter (one codebase → Android/iOS), Riverpod (state),
GoRouter (navigation), OpenStreetMap tiles (no Google Maps billing).

## 3. The five things to demo

1. **Emergency flow** — symptoms → dispatch → driver accepts → live map.
2. **Multi-role account** — one login is both patient and driver; drawer
   toggle flips portal and theme (blue/teal).
3. **Race-safe dispatch** — two drivers tap Accept; second gets a clean
   "already taken" message (HTTP 409), never a double assignment.
4. **Live tracking** — driver GPS streams over WebSocket through Redis
   pub/sub to the patient's map; auto-reconnects on network drops.
5. **Admin** — verify drivers, cancel rides, export CSV, top up wallets.

---

## 4. Likely questions and answers

### Architecture & design

**Q: Why one Flutter app instead of separate patient and driver apps?**
One codebase, one APK, one release pipeline. Roles are a backend concept
(`user_roles` join table), so a single account can hold both. The old
`apps/driver_app` was retired; the unified app toggles portals via the
drawer. Less duplication, and a driver who needs an ambulance for a family
member doesn't need a second app.

**Q: How does authentication work?**
JWT bearer tokens. The token carries `roles[]` (everything the account
holds), `active_role` (the portal currently in use), and a `jti` id.
Logout puts the `jti` on a Redis blocklist, so stolen tokens die at logout
— a fix over plain stateless JWT. Passwords are bcrypt-hashed. Admin
accounts cannot self-register through the API.

**Q: How is authorization decided — by the active portal?**
No — by **held roles plus ownership**. Example: `PATCH /rides/{id}/status`
checks whether the caller's account actually owns the ride as its driver or
patient, regardless of which portal they're in. Checking the active portal
alone would let a multi-role user act on rides that aren't theirs (this was
found in review and fixed, with regression tests in
`backend/tests/test_review_fixes.py`).

**Q: How do you prevent two drivers taking the same ride?**
A single atomic SQL statement:
`UPDATE rides SET driver_id=... WHERE id=... AND driver_id IS NULL`.
The database guarantees only one update succeeds; the loser gets HTTP 409.
No locks, no race window. Covered by `test_accept_second_driver_gets_409`.

**Q: How does live tracking work?**
The driver app opens a WebSocket and streams GPS points. The backend
validates coordinates, persists the driver's position, and publishes each
point to a Redis pub/sub channel keyed by ride id. Every watcher (patient,
family, admin) subscribes to that channel. Auth is sent as the first
WebSocket message instead of in the URL so tokens never appear in server
logs. The server re-reads ride status from the DB during streaming so a
cancelled ride stops broadcasting immediately.

**Q: Why WebSocket + Redis instead of polling?**
Polling at GPS frequency (every few seconds per watcher) multiplies load
and adds latency. Pub/sub fans out one driver update to N watchers in
near-real-time, and Redis decouples the driver's connection from the
watchers' connections (they can be on different server processes).

### Security

**Q: What security measures are in place?**
- bcrypt password hashing; JWT with Redis revocation blocklist
- Strict input validation (Pydantic schemas; phone format enforced)
- Rate limiting **keyed per authenticated user** (not just IP — so carrier NAT
  doesn't make one user throttle another): register/login 5/min, emergency
  5/min, global 200/min
- RBAC by held roles + resource ownership on every ride endpoint
- Missing-credential requests return **401** (not 403) — correct HTTP semantics
- Security headers incl. **HSTS** (force HTTPS), X-Frame-Options, nosniff
- Startup refuses to boot in production with a default SECRET_KEY or
  wildcard CORS
- GPS coordinates validated server-side before persisting
- App stores tokens in flutter_secure_storage (Keychain/EncryptedSharedPrefs);
  Android blocks cleartext traffic; release build is R8-obfuscated

**Q: What about patient privacy / health-data compliance?**
A dedicated PHI audit was done (`docs/PHI_COMPLIANCE_AUDIT.md`). Key points:
- Only the assigned driver, the ride's own patient, and admins can view a ride
  or its GPS stream — verified per-request, with tests.
- **Minimum necessary:** the driver does *not* receive the raw symptom free-text
  — only specialty + severity. The full complaint is shown to the patient and
  admins only.
- **No PHI in logs:** SMS bodies and phone numbers are never logged (phones are
  masked); request logging records method/path/status only, never bodies.
- Hospital pre-alerts reference the patient by **UUID, not name** (FHIR bundle).
- All traffic is HTTPS; error responses carry a `trace_id` (no internal leak).

### Scalability & operations

**Q: How would this scale to more cities?**
The backend is stateless (sessions in JWT/Redis), so it scales
horizontally behind a load balancer. Redis pub/sub already decouples
GPS fan-out across processes. The pending-rides query is capped (100) and
sorted by haversine distance; the next step at scale is a PostGIS spatial
index for true geo-queries — a stated roadmap item, not a rewrite.

**Q: What happens when the network fails mid-ride?**
The app assumes failure: the dispatch screen surfaces "connection lost"
after ~24s of failed polls with a way out; the tracking map auto-reconnects
its WebSocket with exponential backoff and shows a "reconnecting" notice;
family sharing uses SMS, which works without data. Crashes are reported to
Firebase Crashlytics.

**Q: How is the database schema managed?**
Alembic migrations (versioned chain 0001 → 0004: base schema, multi-role,
driver wallet, ride ratings). Migrations are committed and reproducible.

### Testing & quality

**Q: How is the system tested?**
- 81 backend integration tests (pytest + httpx against a test PostgreSQL):
  auth, multi-role, RBAC, dispatch race conditions, websockets, analytics,
  rate-limit keying — at ~65% line coverage, enforced as a CI floor
- 44 Flutter tests (28 app widget/flow + 16 core model/validator)
- CI gates are **real**: tests must pass to merge (previously `|| true` made
  them non-blocking), backend coverage floor enforced, ruff lint + format clean
- `flutter analyze` clean; release APK builds with R8 obfuscation
- **Load/resilience tested by execution** (not just claimed) — see the next Q

**Q: How do you know it holds up under load and failure?**
Four executed tests, results in `docs/LOAD_TEST_RESULTS.md`:
- **Dispatch race:** 50 drivers accept the same ride simultaneously, 10 rounds
  (500 concurrent accepts) → exactly 1 winner every round, 0 double-assignments,
  0 crashes.
- **Endpoint load:** 4100 requests → 0 failures; the rate limiter shed excess
  with clean 429s instead of falling over.
- **Chaos:** killed Redis, then Postgres, mid-run → `/health` stayed 200,
  `/ready` honestly returned 503 naming the dead dependency, auto-recovered when
  it came back (7/7 checks).
- **Soak:** 10 min steady load, 1635 requests → memory flat (+0.6%), DB
  connections steady (no pool leak), 0 errors.

**Q: What was the hardest bug you fixed?**
Authorization used the *active portal* instead of *held roles + ownership*
in two places (ride status updates and the GPS tracking socket). A user
holding both roles could be wrongly blocked — or worse, watch another
ride's GPS. The fix re-checks ownership against the database per request;
regression tests now cover the multi-role matrix.

### AI component

**Q: Where is the AI?**
Two services: symptom **triage** (predicts medical specialty + severity
from free-text symptoms, stored as `TriageEvent` with a confidence score)
and **hospital matching** (chooses a hospital by predicted specialty,
capacity, and distance). Dispatch runs as a FastAPI background task so the
patient's request returns instantly even if triage is slow — and a triage
failure is logged loudly, never silently dropped.

### Honest limitations (say these before they're asked)

- Payments are wallet-based with manual admin top-up; no live payment
  gateway integration yet (JazzCash/EasyPaisa are the roadmap).
- ETA is haversine distance at an assumed average speed, not road routing;
  OSRM/Google Directions is the upgrade path.
- Password reset is via support, not self-service email/SMS flow.
- Single-region deployment; no offline-first data sync.
- In-app account/data deletion not yet shipped (needed before Play Store
  submission — flagged in the PHI audit).

---

## 5. Key numbers to remember

| Metric | Value |
|---|---|
| Backend tests | 81 passing, ~65% coverage (CI floor enforced) |
| Flutter tests | 44 passing (28 app + 16 core) |
| API endpoints | ~35 across auth, rides, drivers, patients, hospitals, analytics, WS |
| DB migrations | 4 (chained, reproducible) |
| Rate limits | 5/min auth & emergency, 200/min global — **keyed per user** |
| Dispatch race handling | atomic UPDATE, HTTP 409 — proven: 500 concurrent, 0 double-books |
| Load proof | 4100 reqs, 0 failures · chaos 7/7 · soak 0 leaks |

---

## 6. Production-readiness hardening

Beyond the FYP feature set, the system was hardened toward a real pilot across
six areas. Each has a dedicated doc in `docs/`.

| Area | What was done | Evidence |
|------|---------------|----------|
| **Testing & CI** | Made CI gates real (were non-blocking), added Flutter flow tests, enforced a backend coverage floor, fixed a 401-vs-403 auth bug | 81 backend + 44 Flutter tests, ruff clean |
| **Security / PHI** | Audited patient-health-data handling; stopped logging PHI, scoped symptom text away from drivers, added HSTS | `PHI_COMPLIANCE_AUDIT.md` |
| **Load & resilience** | Dispatch-race, endpoint-load, chaos (kill Redis/DB), and soak tests — all executed | `LOAD_TEST_RESULTS.md` |
| **Observability** | Sentry error tracking (PHI-safe), ride-lifecycle metrics, Prometheus + Grafana dashboard with alerts | `OBSERVABILITY.md` |
| **Operations** | Backup/restore scripts with a **proven** restore drill, opt-in PgBouncer pooling, release runbook | `OPERATIONS.md` |
| **Mobile release** | Release signing config, R8 shrink/obfuscate (build verified), Play Store data-safety declaration | `PLAY_STORE_DATA_SAFETY.md` |

**One-liner for the panel:** *"It's not just a working demo — the dispatch race
is proven under 500 concurrent accepts with zero double-bookings, it degrades
gracefully when Redis or the database dies, patient health data is handled to a
minimum-necessary standard, and it ships with monitoring, alerting, and a tested
backup/restore."*

**Honest framing:** the hardening is done in code and proven locally; turning it
on for a real pilot still needs operational setup I can't do without credentials
— an upload keystore, production secrets, an alert notification channel, in-app
data deletion, and a staging environment.
