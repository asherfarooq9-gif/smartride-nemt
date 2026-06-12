# Load & Resilience Test Results — SmartRide NEMT

**Date:** 2026-06-12
**Environment:** local docker stack (FastAPI + Postgres/PostGIS + Redis), single host.
**Scripts:** `backend/loadtest.py` (endpoint load), `backend/loadtest_dispatch.py` (dispatch race).

---

## Test 1 — Endpoint load / rate-limiter behavior (`loadtest.py`)

Escalating concurrent requests against `/health` and `/ready`.

| Wave | Reqs | 2xx | 429 throttled | 5xx / conn fail |
|------|------|-----|---------------|-----------------|
| 100 @ 20 | 100 | 100 | 0 | 0 |
| 500 @ 50 | 500 | 99 | 401 | 0 |
| 1000 @ 100 | 1000 | 0 | 1000 | 0 |
| 2000 @ 200 | 2000 | 200 | 1800 | 0 |
| /ready @ 50 | 500 | 200 | 300 | 0 |

**Result:** server never crashed — **0 failures across 4100 requests**. The slowapi
limiter (200/min/IP) shed excess load with clean `429`s instead of falling over.
`/ready` (which touches Postgres + Redis) stayed at 0 failures under 50 concurrent.

> Caveat: all traffic originated from one IP, so the per-IP limiter is the ceiling
> here, not raw capacity. Real users span many IPs → much higher real ceiling.

---

## Test 2 — Dispatch race under concurrency (`loadtest_dispatch.py`)

The critical correctness test: **50 verified drivers POST `/accept` on the SAME
pending ride simultaneously**, repeated for 10 rounds (500 concurrent accepts).
The assignment is an atomic
`UPDATE rides ... WHERE status='pending' AND driver_id IS NULL RETURNING` —
exactly one driver must win.

| Metric | Value |
|--------|-------|
| Rounds | 10 |
| Drivers per round | 50 |
| Total accept calls | 500 |
| Winners per round | 1, every round |
| Total `409` conflicts | 490 |
| Errors / double-assignments | **0** |
| Accept latency p50 / p95 / p99 | 957 / 2009 / 2224 ms |

**Result: PASS** — exactly one winner every round, no double-assignment. The DB row
confirmed a single `driver_id` set per ride each round. The losing 49 drivers each
got a clean `409 Ride already taken`, never a 500 or a phantom second assignment.

> Latency rises under 50-way contention for a single row (all writers serialize on
> the same lock) but no request failed. Real dispatch fans many drivers across many
> *different* pending rides, so this is a worst-case contention bound, not typical load.

---

## Test 3 — Chaos / graceful degradation (`scripts/chaos_test.sh`)

Kill each backing service in turn; the API must degrade honestly, not crash, and
recover when the service returns.

| Phase | health | ready | Result |
|-------|--------|-------|--------|
| Baseline | 200 | 200 (db✓ redis✓) | PASS |
| Redis down | 200 | 503 (redis=false) | PASS |
| Redis restored | — | 200 | PASS (auto-recover) |
| Postgres down | 200 | 503 (db=false) | PASS |
| Postgres restored | — | 200 | PASS (auto-recover) |

**Result: 7/7 PASS.** `/health` (liveness) stayed 200 throughout — it doesn't
depend on backing services, so orchestrators won't needlessly kill the pod.
`/ready` (readiness) honestly reported 503 with the exact failed dependency, so a
load balancer would stop routing until recovery. `pool_pre_ping=True` let the DB
connection pool recover automatically after Postgres returned — no restart needed.

## Follow-ups (not yet done)

- Soak test (sustained traffic 30+ min) to surface memory / connection-pool leaks.
- Per-user rate limiting (NAT'd mobile users share IPs; per-IP alone can throttle
  legitimate users).
