# Spec: Scheduled rides (driver Scheduled tab), repeat bookings, cash, Urdu

Status: DRAFT v2, awaiting approval. No code written for this spec.

## Scope decision (latest, overrides anything below that conflicts)

- **Emergency = the "now" ride.** There is no separate instant / live non-emergency ride, no InDrive-style bidding, and no Now | Later toggle. Patient home has two paths: **Emergency** (now, auto-dispatch) and **Schedule** (later).
- **In scope:** driver Scheduled tab with claim/release (below), **repeat bookings**, **driver payment methods** (the driver lists which methods they accept, such as Easypaisa, JazzCash, bank transfer or cash, on their profile, and the patient sees them once the driver is assigned; the app does not process or record payments), **Urdu**.
- **Driver portal has two clear sections:** **Emergency** (the Home tab, live map with emergency requests) and **Scheduled** (its own tab). Bottom bar becomes Emergency, Scheduled, Earnings, Profile.
- **Out of scope for now:** instant rides, price bidding, vehicle types, booking for someone else, digital payments.
- **Dependency:** repeat bookings create many scheduled rides, so the duplicate-booking fix (`docs/adr/PROPOSAL-scheduled-ride-idempotency.md`) must land first.
- **Order:** idempotency, then Scheduled tab + claims, then repeat bookings, then cash, with Urdu running alongside.
- Sections below about the Now | Later toggle are superseded by the first bullet.

## Objective

Make scheduled (booked-ahead) NEMT rides plannable instead of invisible.

- **Driver**: Home shows only live requests near them. A new **Scheduled** tab lists upcoming booked rides and lets the driver claim one ahead of time.
- **Patient**: booking starts with a **Now | Later** choice. Emergency stays a separate one-tap button and never shows that choice.
- **Backend**: list scheduled rides, claim, driver-cancel, and no-show handling, with race and resilience tests.

Why: a scheduled ride is hidden from drivers until 30 minutes before pickup (`SCHEDULED_DISPATCH_LEAD_MINUTES`), so a driver cannot plan around it and a patient with a fixed appointment (dialysis, follow-up) has no guaranteed pickup.

Users: verified drivers, patients booking non-emergency trips.

## Assumptions (correct me now)

1. Live nearby radius is 10 km (`DRIVER_SEARCH_RADIUS_KM`, already changed). The Scheduled tab uses the same radius from the driver's current location.
2. Claiming ahead does not make the driver "busy". Driver status stays `available` until the claimed ride's pickup window opens.
3. A claimed ride stays in the pool as a fallback: if the driver cancels or is a no-show it returns to `pending` and is dispatched normally.
4. Emergency dispatch is unchanged. Its radius also became 10 km because it shares the setting; see Open Questions.
5. Patient app and driver app are one Flutter app (`apps/patient_app`), switched by role.
6. Scheduled-ride creation idempotency is a separate proposal (`docs/adr/PROPOSAL-scheduled-ride-idempotency.md`, status PROPOSED). This spec does not depend on it, but both change `ride_service.py` and `rides.py`, so they must not be built concurrently.

## Tech stack

Backend: FastAPI, SQLAlchemy async, PostgreSQL/PostGIS, Redis, Alembic. Client: Flutter, Riverpod, go_router.

## Commands

```bash
docker compose up -d postgres redis
cd backend && pytest -v --tb=short
cd backend && ruff check . && ruff format --check .
cd apps/patient_app && flutter analyze && flutter test
make test            # backend
make test-flutter    # core package + patient app
```

Note: the host Python has no `pytest_asyncio`, so backend tests need the project's dev dependencies installed first (not done yet).

## Project structure (files likely touched)

```
backend/app/routers/rides.py          new endpoints
backend/app/services/ride_service.py  list_scheduled_rides, claim/release logic
backend/app/models/models.py          claim fields on Ride (migration)
backend/alembic/versions/             expand-only migration
backend/tests/                        test_scheduled_claims.py (+ races)
docs/api-contract.md                  new endpoints
apps/patient_app/lib/driver/          driver_nav_bar.dart, new scheduled_tab screen
apps/patient_app/lib/features/rides/  home_sheet_parts.dart (Now | Later)
apps/patient_app/lib/core/router.dart new route
```

## Behaviour

### Patient
- Booking entry shows a segmented control **Now | Later**. Now opens the existing instant flow. Later opens `schedule_trip_screen.dart`.
- The emergency button is outside the control and unchanged.

### Driver
- Home: live pending rides only (not scheduled), within 10 km, nearest first, as today.
- Scheduled tab: scheduled rides that are `pending` and unclaimed, within 10 km of the driver, sorted by `scheduled_for` ascending, plus the driver's own claimed rides at the top. Shows date, time, pickup area and fare estimate.
- Claim: driver taps Claim. Server reserves the ride for that driver. Patient is notified that a driver is assigned.
- Cancel claim: allowed until a cutoff before pickup (default 60 min). Ride returns to `pending`, patient notified.
- No-show: if the claimed driver is not online and within range at `scheduled_for - lead`, the system releases the claim and dispatches normally.
- At `scheduled_for - lead` a claimed ride moves into the driver's normal active-ride flow.

### API (draft, to be added to `docs/api-contract.md`)

| Endpoint | Auth | Behaviour |
|---|---|---|
| `GET /rides/scheduled/open` | verified driver | Unclaimed scheduled rides in radius, soonest first. Capped list. |
| `GET /rides/scheduled/mine` | verified driver | The driver's claimed upcoming rides. |
| `POST /rides/{id}/claim` | verified driver | Atomic claim. `409` if taken, not scheduled, out of radius, or the driver has an overlapping claim. |
| `POST /rides/{id}/release` | claiming driver | Release before cutoff. `409` after cutoff. |

## Code style

Match the repo: async services, thin routers, atomic conditional UPDATE for claims (same pattern as `accept` in `ride_service.py`: claim with `WHERE status = pending AND driver_id IS NULL`, check rowcount). Dart: `final`, trailing commas, `package:` imports, `on` clauses with exception types.

## Testing strategy

Follow `backend/tests/test_dispatch_races.py` and `test_money.py`. Test first.

- Two drivers claim one ride concurrently: exactly one `200`, one `409`.
- Claim of a non-scheduled or already-accepted ride: `409`.
- Out-of-radius claim: `409`. Driver without location: empty list.
- Overlapping claims for one driver (time window): `409`.
- Release after cutoff: `409`. Release returns ride to `pending` and it is dispatchable again.
- No-show release does not resurrect a cancelled ride (same shape as the existing resurrect test).
- Claim never changes wallet or fare; money logic is not touched.
- Migration up/down passes `backend/tests/test_migrations.py`.
- Flutter: widget tests for the Now | Later control, the Scheduled tab empty and populated states, and that the emergency button does not show the control.

## Boundaries

- Always: write the failing test first; keep migrations expand-only; run ruff and flutter analyze before committing; update `docs/api-contract.md` with the endpoints.
- Ask first: the migration itself, any change to emergency dispatch or radius, adding dependencies, push notification wording sent to patients.
- Never: touch money or payout logic, weaken or skip a test, commit secrets, edit another session's uncommitted files, or commit to `main`.

## Success criteria

1. Driver Home never lists scheduled rides; the Scheduled tab does.
2. Two concurrent claims on one ride produce exactly one winner.
3. A claimed ride the driver cancels or misses is back in the pool before pickup.
4. A patient can choose Now or Later in one tap, and emergency is still one tap with no extra step.
5. All CI checks in `CLAUDE.md` pass.

## Delivery order (each a thin vertical slice, one commit per task)

1. Patient Now | Later control (UI only).
2. Driver Scheduled tab, read-only, backed by `GET /rides/scheduled/open`.
3. Claim, release and no-show, with the migration and race tests.

## Open questions

1. **Emergency radius.** Emergency dispatch shares `DRIVER_SEARCH_RADIUS_KM`, so it is now 10 km too. Keep, or give emergencies their own wider radius (suggest 25 km)?
2. **Release cutoff.** 60 minutes before pickup acceptable?
3. **Claim limit.** Max number of ahead-claims per driver at once?
4. **Notifications.** Patient push on claim and on release. Also SMS to the family contact, as on manual accept?
5. **Schema.** New nullable `claimed_driver_id` column on `rides` (simple) or a separate claims table? I suggest the column.
6. **Sequencing with the idempotency proposal.** Build it first, after, or independently?
