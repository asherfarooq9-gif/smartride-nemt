"""Dispatch-race + authenticated write-path load test for SmartRide.

Two things under test that the health-check load test could not reach:

1. CORRECTNESS UNDER CONCURRENCY — many verified drivers POST /accept on the
   SAME pending ride simultaneously. The atomic
   `UPDATE rides ... WHERE status='pending' AND driver_id IS NULL RETURNING`
   must let *exactly one* win (200) and everyone else lose (409). Zero
   double-assignments across all rounds is the pass condition.

2. REAL DB-WRITE THROUGHPUT — latency of the accept write path under load,
   not just a static health endpoint.

Setup is seeded directly in Postgres (asyncpg) so the per-IP rate limiter on
/emergency doesn't cap how many rounds we can run.

Run with the docker stack up:  python loadtest_dispatch.py
"""

import asyncio
import os
import statistics
import time
import uuid

import asyncpg
import httpx

# Runs inside the backend container, so it can mint real JWTs directly and
# skip the per-IP auth rate limiter that would otherwise cap how many distinct
# drivers we can stand up. Tokens are identical in shape to a normal login.
from app.core.security import create_access_token

BASE = os.getenv("LOADTEST_BASE", "http://localhost:8000")
PG = os.getenv(
    "LOADTEST_PG", "postgresql://smartride:password@localhost:5432/smartride"
)

N_DRIVERS = 50
N_ROUNDS = 10


async def _register(client: httpx.AsyncClient, body: dict) -> str | None:
    r = await client.post("/api/v1/auth/register", json=body, timeout=15.0)
    if r.status_code == 201:
        return r.json()["access_token"]
    # Phone may already exist from a previous run — fall back to login.
    r = await client.post(
        "/api/v1/auth/login",
        json={"phone": body["phone"], "password": body["password"]},
        timeout=15.0,
    )
    return r.json()["access_token"] if r.status_code == 200 else None


def _mint(user_id: uuid.UUID, role: str) -> str:
    return create_access_token(
        {"sub": str(user_id), "roles": [role], "active_role": role, "role": role}
    )


async def setup(client: httpx.AsyncClient, pg: asyncpg.Connection):
    run = f"{int(time.time() * 1000) % 1000000:06d}"

    # Patient — user + patient row, then mint a token.
    patient_uid = uuid.uuid4()
    await pg.execute(
        "INSERT INTO users (id, phone, password_hash, role, is_active) "
        "VALUES ($1, $2, 'x', 'patient', true)",
        patient_uid,
        f"+9230{run}",
    )
    await pg.execute(
        "INSERT INTO user_roles (id, user_id, role) VALUES ($1, $2, 'patient')",
        uuid.uuid4(),
        patient_uid,
    )
    patient_id = uuid.uuid4()
    await pg.execute(
        "INSERT INTO patients (id, user_id, full_name) VALUES ($1, $2, 'LoadTest Patient')",
        patient_id,
        patient_uid,
    )

    # Drivers — user + user_roles + verified driver row, then mint tokens.
    tokens: list[str] = []
    driver_user_ids: list[uuid.UUID] = []
    for i in range(N_DRIVERS):
        uid = uuid.uuid4()
        await pg.execute(
            "INSERT INTO users (id, phone, password_hash, role, is_active) "
            "VALUES ($1, $2, 'x', 'driver', true)",
            uid,
            f"+9231{run}{i:03d}"[:15],
        )
        await pg.execute(
            "INSERT INTO user_roles (id, user_id, role) VALUES ($1, $2, 'driver')",
            uuid.uuid4(),
            uid,
        )
        await pg.execute(
            "INSERT INTO drivers (id, user_id, full_name, license_no, vehicle_plate, "
            "vehicle_type, is_verified, status, current_lat, current_lng) "
            "VALUES ($1, $2, $3, $4, $5, 'Ambulance', true, 'available', 33.6844, 73.0479)",
            uuid.uuid4(),
            uid,
            f"LoadTest Driver {i}",
            f"LT-{run}-{i}",
            f"LT{run}{i:03d}"[:20],
        )
        tokens.append(_mint(uid, "driver"))
        driver_user_ids.append(uid)

    return patient_id, tokens, driver_user_ids


async def seed_ride(pg: asyncpg.Connection, patient_id) -> str:
    ride_id = uuid.uuid4()
    await pg.execute(
        "INSERT INTO rides (id, patient_id, ride_type, status, pickup_lat, pickup_lng) "
        "VALUES ($1, $2, 'emergency', 'pending', 33.6850, 73.0480)",
        ride_id,
        patient_id,
    )
    return str(ride_id)


async def race_round(tokens: list[str], ride_id: str) -> tuple[list[int], list[float]]:
    async def accept(token: str) -> tuple[int, float]:
        start = time.perf_counter()
        async with httpx.AsyncClient(base_url=BASE) as c:
            try:
                r = await c.post(
                    f"/api/v1/rides/{ride_id}/accept",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=15.0,
                )
                return r.status_code, (time.perf_counter() - start) * 1000
            except Exception:
                return 0, (time.perf_counter() - start) * 1000

    results = await asyncio.gather(*(accept(t) for t in tokens))
    return [c for c, _ in results], [ms for _, ms in results]


async def main():
    pg = await asyncpg.connect(PG)
    try:
        async with httpx.AsyncClient(base_url=BASE) as client:
            print(f"Setting up 1 patient + {N_DRIVERS} verified drivers ...")
            patient_id, tokens, driver_uids = await setup(client, pg)
            print(f"Ready: {len(tokens)} drivers authenticated.\n")

        all_latencies: list[float] = []
        wins_per_round: list[int] = []
        total_409 = total_other = 0

        for rnd in range(1, N_ROUNDS + 1):
            ride_id = await seed_ride(pg, patient_id)
            codes, lats = await race_round(tokens, ride_id)
            all_latencies += lats
            wins = sum(1 for c in codes if c == 200)
            conflicts = sum(1 for c in codes if c == 409)
            other = len(codes) - wins - conflicts
            total_409 += conflicts
            total_other += other
            wins_per_round.append(wins)

            # Confirm the DB really assigned exactly one driver for this ride.
            assigned = await pg.fetchval(
                "SELECT driver_id FROM rides WHERE id = $1", uuid.UUID(ride_id)
            )
            flag = "OK" if wins == 1 and assigned is not None else "!! FAIL"
            print(
                f"round {rnd:2d}: winners={wins} conflicts={conflicts} "
                f"other={other} db_driver={'set' if assigned else 'NULL'}  [{flag}]"
            )

            # Reset drivers to available for the next round.
            await pg.execute(
                "UPDATE drivers SET status = 'available' "
                "WHERE user_id = ANY($1::uuid[])",
                driver_uids,
            )

        lat_sorted = sorted(all_latencies)

        def pct(p):
            return lat_sorted[min(len(lat_sorted) - 1, int(len(lat_sorted) * p))]

        total_accepts = len(tokens) * N_ROUNDS
        print("\n=== Dispatch race summary ===")
        print(f"rounds                 : {N_ROUNDS}")
        print(f"drivers per round      : {len(tokens)}")
        print(f"total accept calls     : {total_accepts}")
        print(f"winners (expect 1/rnd) : {wins_per_round}")
        print(f"total 409 conflicts    : {total_409}")
        print(f"other/errors           : {total_other}")
        print(f"accept latency p50     : {statistics.median(all_latencies):.1f} ms")
        print(f"accept latency p95     : {pct(0.95):.1f} ms")
        print(f"accept latency p99     : {pct(0.99):.1f} ms")
        ok = all(w == 1 for w in wins_per_round) and total_other == 0
        print(
            f"\nRESULT: {'PASS — exactly one winner every round, no double-assignment' if ok else 'FAIL — investigate'}"
        )
    finally:
        await pg.close()


if __name__ == "__main__":
    asyncio.run(main())
