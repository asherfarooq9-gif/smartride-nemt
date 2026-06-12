"""Soak test — sustained steady load to surface leaks over time.

Fires a constant ~3 req/s (under the 200/min limiter, so we measure the server
not the limiter) against /health and /ready for SOAK_SECONDS, sampling backend
memory and Postgres connection count every SAMPLE_SECONDS.

What we're hunting:
  - memory growth  -> a leak
  - connection growth -> a pool/session leak
  - latency creep / rising errors -> degradation under sustained load

Run on the host with the docker stack up:
  python scripts/soak_test.py            # default 15 min
  SOAK_SECONDS=1800 python scripts/soak_test.py   # 30 min
"""

import os
import subprocess
import time

import httpx

BASE = os.getenv("SOAK_BASE", "http://localhost:8000")
SOAK_SECONDS = int(os.getenv("SOAK_SECONDS", "900"))
SAMPLE_SECONDS = int(os.getenv("SOAK_SAMPLE_SECONDS", "30"))
TARGET_RPS = float(os.getenv("SOAK_RPS", "3"))


def backend_mem_mib() -> float:
    try:
        out = subprocess.check_output(
            ["docker", "stats", "--no-stream", "--format", "{{.MemUsage}}",
             "smartride_backend"],
            text=True, timeout=15,
        ).strip()
        raw = out.split("/")[0].strip()  # e.g. "123.4MiB"
        num = float("".join(c for c in raw if (c.isdigit() or c == ".")))
        if "GiB" in raw:
            num *= 1024
        return num
    except Exception:
        return -1.0


def pg_connections() -> int:
    try:
        out = subprocess.check_output(
            ["docker", "exec", "-e", "PGPASSWORD=password", "smartride_postgres",
             "psql", "-U", "smartride", "-tAc",
             "SELECT count(*) FROM pg_stat_activity WHERE datname='smartride'"],
            text=True, timeout=15,
        ).strip()
        return int(out)
    except Exception:
        return -1


def main() -> None:
    paths = ["/health", "/ready"]
    interval = 1.0 / TARGET_RPS
    deadline = time.time() + SOAK_SECONDS
    next_sample = time.time()
    sent = errors = 0
    latencies: list[float] = []
    samples: list[tuple[int, float, int, float]] = []  # (t, mem, conns, p50)
    i = 0

    print(f"Soak: {SOAK_SECONDS}s @ ~{TARGET_RPS} req/s, sampling every {SAMPLE_SECONDS}s\n")
    with httpx.Client(base_url=BASE, timeout=10.0) as client:
        start = time.time()
        while time.time() < deadline:
            path = paths[i % len(paths)]
            i += 1
            t0 = time.perf_counter()
            try:
                r = client.get(path)
                latencies.append((time.perf_counter() - t0) * 1000)
                # /ready is 200 normally; 5xx or connection error counts as failure.
                if r.status_code >= 500:
                    errors += 1
            except Exception:
                errors += 1
            sent += 1

            now = time.time()
            if now >= next_sample:
                window = sorted(latencies[-200:]) or [0]
                p50 = window[len(window) // 2]
                mem = backend_mem_mib()
                conns = pg_connections()
                elapsed = int(now - start)
                samples.append((elapsed, mem, conns, p50))
                print(f"  t={elapsed:4d}s  mem={mem:7.1f}MiB  pg_conns={conns:3d}  "
                      f"p50={p50:6.1f}ms  sent={sent}  errors={errors}")
                next_sample = now + SAMPLE_SECONDS

            time.sleep(interval)

    print("\n=== Soak summary ===")
    print(f"duration        : {SOAK_SECONDS}s")
    print(f"requests sent   : {sent}")
    print(f"errors (5xx/conn): {errors}")
    if samples:
        first_mem, last_mem = samples[0][1], samples[-1][1]
        first_conn, last_conn = samples[0][2], samples[-1][2]
        max_conn = max(s[2] for s in samples)
        growth = (last_mem - first_mem)
        growth_pct = (growth / first_mem * 100) if first_mem > 0 else 0
        print(f"memory start    : {first_mem:.1f} MiB")
        print(f"memory end      : {last_mem:.1f} MiB  (delta {growth:+.1f} MiB, {growth_pct:+.1f}%)")
        print(f"pg conns start/end/max : {first_conn} / {last_conn} / {max_conn}")
        # Heuristic verdict: <15% memory growth and connections not climbing.
        mem_ok = growth_pct < 15
        conn_ok = max_conn <= first_conn + 10
        verdict = "PASS" if (mem_ok and conn_ok and errors == 0) else "REVIEW"
        print(f"\nRESULT: {verdict} "
              f"(mem_ok={mem_ok}, conn_ok={conn_ok}, errors={errors})")


if __name__ == "__main__":
    main()
