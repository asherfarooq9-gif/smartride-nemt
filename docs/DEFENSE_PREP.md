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
- Rate limiting: register/login 5/min, emergency rides 5/min, global 200/min
- RBAC by held roles + resource ownership on every ride endpoint
- Startup refuses to boot in production with a default SECRET_KEY or
  wildcard CORS
- GPS coordinates validated server-side before persisting
- App stores tokens in flutter_secure_storage (Keychain/EncryptedSharedPrefs)

**Q: What about patient privacy?**
Only the assigned driver, the ride's own patient, and admins can view a
ride or its GPS stream — verified per-request, with tests. Error messages
don't leak internals; notification failures are logged server-side only.

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
- 77 backend integration tests (pytest + httpx against a test PostgreSQL):
  auth, multi-role, RBAC, dispatch race conditions, websockets, analytics
- 36 Flutter tests (widget + model + validator)
- `flutter analyze` clean; CI builds via Codemagic
- Review-driven regression tests pin the security fixes so they can't
  silently regress

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
- The notification list mixes live push messages with seeded examples.
- Single-region deployment; no offline-first data sync.

---

## 5. Key numbers to remember

| Metric | Value |
|---|---|
| Backend tests | 77 passing |
| Flutter tests | 36 passing |
| API endpoints | ~35 across auth, rides, drivers, patients, hospitals, analytics, WS |
| DB migrations | 4 (chained, reproducible) |
| Rate limits | 5/min auth & emergency, 200/min global |
| Dispatch race handling | atomic UPDATE, HTTP 409 on conflict |
