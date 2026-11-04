# Proposal: durable idempotency for ride creation (QA finding F3)

Status: PROPOSED. Nothing in this document has been implemented or run. A migration needs explicit approval before it is written or applied.

## Problem

`POST /rides/scheduled` (`backend/app/routers/rides.py`) deduplicates only through a Redis key written after the ride commits (`backend/app/services/idempotency.py`, `SET NX`, 300 s TTL, fails open).

1. Two concurrent requests with one key can both pass `recall` and create two rides.
2. If Redis is down, every retry creates another ride.
3. A crash between the commit and `remember` loses the key.
4. The patient app sends no key for scheduled rides (`schedule_trip_screen.dart`), so a double tap or timeout retry duplicates a booking. The emergency screen does send one.
5. Emergency creation is protected by the partial unique index `uq_rides_active_emergency_per_patient`, so it is much safer. Scheduled rides have no equivalent, and there is no natural business key (a patient may legitimately book several).

## Proposed design

A small table owned by the database, written in the same transaction as the ride.

```
ride_idempotency_keys
  patient_id   uuid  NOT NULL  REFERENCES patients(id)
  scope        text  NOT NULL            -- 'scheduled' | 'emergency'
  key          text  NOT NULL            -- validated by idempotency.validate_key
  fingerprint  text  NOT NULL            -- same digest as today
  ride_id      uuid  NOT NULL  REFERENCES rides(id) ON DELETE CASCADE
  created_at   timestamptz NOT NULL DEFAULT now()
  PRIMARY KEY (patient_id, scope, key)
```

Request flow for `create_scheduled_ride`:

1. Validate key. If absent, behave as today.
2. `INSERT ... ON CONFLICT (patient_id, scope, key) DO NOTHING` together with the ride insert, in one transaction.
3. If the key row already existed: load its ride. Same fingerprint returns 200 with that ride. Different fingerprint returns 409 (current behaviour).
4. Keep the Redis path as a fast-path cache only. The database is the source of truth, so a Redis outage no longer allows duplicates.

Retention: delete rows older than 24 h with a scheduled job (the same loop host as `dispatch_loop`, or a cron). A longer window than the 300 s Redis TTL also covers slow client retries.

Client change (separate, Flutter, not owned by this session): generate one key per booking attempt and reuse it on retry, as `symptom_screen.dart` does with `_keyFor`.

## Migration plan (expand / contract, per CLAUDE.md)

0. Revision chain: current head is `0010` (`0010_trigram_search_indexes.py`), so the new file is `0011` with `down_revision = "0010"`. Re-check the head right before writing it, since other sessions may add revisions.
1. Expand: new Alembic revision creating the table. Purely additive, so it needs no lock beyond table creation and is safe to deploy before the code.
2. Code: write the key row in the same transaction; keep reading the Redis key as a cache.
3. Backfill: none needed. Old Redis keys expire on their own.
4. Contract: none. The Redis path stays as a cache, so nothing is dropped.
5. Rollback: the table can be left in place; reverting the code restores today's behaviour.

Must pass `backend/tests/test_migrations.py`.

## Code touch points (checked against the tree, not edited)

- `routers/rides.py` `create_scheduled_ride`: today it is `recall` (Redis read) then `ride_service.create_scheduled_ride` then `remember` (Redis write), three separate steps with no lock. The race is the gap between the read and the write.
- `ride_service.create_scheduled_ride` must accept the key and fingerprint so the ride insert and the key insert share one commit. This file and `rides.py` are currently modified by another session, so this change waits for their commit.
- Conflict handling: on a unique-violation of `(patient_id, scope, key)`, roll back, load the existing row's ride, compare fingerprints. Reuse the pattern already used for `_ACTIVE_EMERGENCY_INDEX` in `rides.py`.
- `rides.patient_id` references `patients.id`; the new FK must match its type (confirm in `models.py` before writing the revision).

## Tests that would prove it

- Two concurrent scheduled POSTs with one key (`asyncio.gather`, separate sessions, `isolated_client`) produce exactly one ride and one 201 plus one 200.
- Same, with Redis made unavailable.
- Same key, different body returns 409.
- Same key from two different patients creates two rides.
- A crash after the ride insert but before the response leaves the key row, so the retry returns the same ride (simulate with an exception after commit).
- Migration upgrade and downgrade round trip.

## Alternatives considered

- Unique constraint on `(patient_id, scheduled_for, pickup)`: breaks legitimate repeat bookings; rejected.
- Add an `idempotency_key` column on `rides`: simpler, one fewer table, but it clutters a hot table, and the fingerprint and scope still need somewhere to live. Reasonable if you prefer fewer objects; the semantics are the same.
- Redis-only with `SET NX` before the insert: narrows the race but still fails open when Redis is down; rejected.

## Open questions for approval

1. Table or `rides` column?
2. Retention window (24 h proposed).
3. Should emergency creation also move to the table, or keep its existing index as the guard?
4. Who owns the Flutter change to send a key on the schedule screen?
