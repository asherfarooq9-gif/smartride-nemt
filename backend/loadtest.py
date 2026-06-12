"""Ad-hoc load test for the SmartRide API.

Fires escalating waves of concurrent requests and reports throughput,
latency percentiles, and the split between handled (2xx), throttled
(429 from slowapi), and failed (5xx / connection errors) responses.

Run while the docker stack is up:  python loadtest.py
"""

import asyncio
import statistics
import time

import httpx

BASE = "http://localhost:8000"
# Endpoints that don't need auth — safe to hammer.
TARGETS = ["/health", "/ready"]


async def fire(client: httpx.AsyncClient, path: str) -> tuple[int, float]:
    start = time.perf_counter()
    try:
        r = await client.get(path, timeout=10.0)
        return r.status_code, (time.perf_counter() - start) * 1000
    except Exception:
        return 0, (
            time.perf_counter() - start
        ) * 1000  # 0 == connection/timeout failure


async def wave(total: int, concurrency: int, path: str) -> None:
    limits = httpx.Limits(
        max_connections=concurrency, max_keepalive_connections=concurrency
    )
    sem = asyncio.Semaphore(concurrency)
    results: list[tuple[int, float]] = []

    async with httpx.AsyncClient(base_url=BASE, limits=limits) as client:

        async def one() -> None:
            async with sem:
                results.append(await fire(client, path))

        wall_start = time.perf_counter()
        await asyncio.gather(*(one() for _ in range(total)))
        wall = time.perf_counter() - wall_start

    codes = [c for c, _ in results]
    lat = [ms for _, ms in results]
    ok = sum(1 for c in codes if 200 <= c < 300)
    throttled = sum(1 for c in codes if c == 429)
    failed = sum(1 for c in codes if c == 0 or c >= 500)
    other = len(codes) - ok - throttled - failed

    lat_sorted = sorted(lat)

    def pct(p: float) -> float:
        if not lat_sorted:
            return 0.0
        idx = min(len(lat_sorted) - 1, int(len(lat_sorted) * p))
        return lat_sorted[idx]

    print(f"\n=== {path}  |  {total} reqs @ concurrency {concurrency} ===")
    print(f"wall time      : {wall:.2f}s")
    print(f"throughput     : {total / wall:.0f} req/s")
    print(f"2xx handled    : {ok}")
    print(f"429 throttled  : {throttled}")
    print(f"5xx/conn fail  : {failed}")
    if other:
        print(f"other          : {other}")
    print(f"latency p50    : {statistics.median(lat):.1f} ms")
    print(f"latency p95    : {pct(0.95):.1f} ms")
    print(f"latency p99    : {pct(0.99):.1f} ms")
    print(f"latency max    : {max(lat):.1f} ms")


async def main() -> None:
    # Escalating load. Each wave is its own minute-ish window; the 200/min
    # slowapi cap means big waves will show heavy 429s — that's the limiter
    # protecting the server, not the server falling over.
    plans = [
        (100, 20, "/health"),
        (500, 50, "/health"),
        (1000, 100, "/health"),
        (2000, 200, "/health"),
        (500, 50, "/ready"),
    ]
    for total, conc, path in plans:
        await wave(total, conc, path)


if __name__ == "__main__":
    asyncio.run(main())
