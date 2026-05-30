"""
SmartRide end-to-end API smoke test.
Runs against http://localhost:8000 -- no device needed.

Driver assignment is done via direct DB update (the backend has no
accept-ride endpoint; dispatch is handled by the admin dashboard).
"""

import asyncio
import json
import subprocess
import sys
import time
import httpx
import websockets

BASE    = "http://localhost:8000/api/v1"
WS_BASE = "ws://localhost:8000"
PG_ARGS = ["docker", "exec", "smartride_postgres",
           "psql", "-U", "smartride", "-d", "smartride", "-c"]

TS            = int(time.time())
PATIENT_PHONE = f"+9232{TS % 10000000:07d}"
DRIVER_PHONE  = f"+9233{TS % 10000000:07d}"
PASSWORD      = "Test1234!"

PASS  = "[OK]  "
FAIL  = "[FAIL]"
errors: list[str] = []

def ok(label, _=""):
    print(f"  {PASS} {label}")

def fail(label, detail=""):
    print(f"  {FAIL} {label}" + (f"  ->  {detail[:120]}" if detail else ""))
    errors.append(label)

def check(label, condition, detail=""):
    (ok if condition else fail)(label, "" if condition else detail)

def section(title):
    print(f"\n{'-'*55}\n  {title}\n{'-'*55}")

def psql(sql: str) -> str:
    r = subprocess.run(PG_ARGS + [sql], capture_output=True, text=True)
    return (r.stdout + r.stderr).strip()

# ── 1. Health ─────────────────────────────────────────────

section("1. Health check")
with httpx.Client(timeout=10) as c:
    r = c.get("http://localhost:8000/health")
    check("GET /health -> 200", r.status_code == 200, r.text)

# ── 2. Register ───────────────────────────────────────────

section("2. Register patient + driver")
with httpx.Client(base_url=BASE, timeout=10) as c:
    r = c.post("/auth/register", json={
        "phone": PATIENT_PHONE, "password": PASSWORD,
        "full_name": "Smoke Patient", "role": "patient",
    })
    check("Register patient -> 201", r.status_code == 201, r.text)

    r = c.post("/auth/register", json={
        "phone": DRIVER_PHONE, "password": PASSWORD,
        "full_name": "Smoke Driver", "role": "driver",
        "license_no": f"LIC{TS}", "vehicle_plate": f"SMK{TS%1000:03d}",
        "vehicle_type": "Sedan",
    })
    check("Register driver -> 201", r.status_code == 201, r.text)

# ── 3. Login ──────────────────────────────────────────────

section("3. Login")
patient_token = driver_token = ""
with httpx.Client(base_url=BASE, timeout=10) as c:
    r = c.post("/auth/login", json={"phone": PATIENT_PHONE, "password": PASSWORD})
    check("Patient login -> 200", r.status_code == 200, r.text)
    patient_token = r.json().get("access_token", "") if r.status_code == 200 else ""
    check("Patient JWT present", bool(patient_token))

    r = c.post("/auth/login", json={"phone": DRIVER_PHONE, "password": PASSWORD})
    check("Driver login -> 200", r.status_code == 200, r.text)
    driver_token = r.json().get("access_token", "") if r.status_code == 200 else ""
    check("Driver JWT present", bool(driver_token))

if not patient_token or not driver_token:
    print("\n[ABORT] Login failed -- cannot continue.")
    sys.exit(1)

ph = {"Authorization": f"Bearer {patient_token}"}
dh = {"Authorization": f"Bearer {driver_token}"}

# ── 4. Driver goes online + get DB id ─────────────────────

section("4. Driver goes online")
driver_db_id = ""
with httpx.Client(base_url=BASE, timeout=10) as c:
    r = c.patch("/drivers/status", json={"status": "available"}, headers=dh)
    check("PATCH /drivers/status -> 200", r.status_code == 200, r.text)

    r = c.get("/drivers/me", headers=dh)
    check("Driver status == available", r.json().get("status") == "available", r.text)
    driver_db_id = r.json().get("id", "")
    print(f"         driver DB id = {driver_db_id}")

# ── 5. Patient creates emergency ride ─────────────────────

section("5. Create emergency ride")
ride_id = ""
with httpx.Client(base_url=BASE, timeout=15) as c:
    r = c.post("/rides/emergency", json={
        "pickup_address": "H-8 Islamabad",
        "symptom_text":   "Chest pain and difficulty breathing",
        "pickup_lat":     33.6844,
        "pickup_lng":     73.0479,
    }, headers=ph)
    check("POST /rides/emergency -> 201", r.status_code == 201, r.text)
    ride_id = r.json().get("id", "") if r.status_code == 201 else ""
    check("Ride ID returned", bool(ride_id))
    if ride_id:
        print(f"         ride_id = {ride_id}")

if not ride_id or not driver_db_id:
    print("\n[ABORT] Missing ride_id or driver_db_id.")
    sys.exit(1)

# ── 6. Assign driver via DB (no accept endpoint) ──────────

section("6. Assign driver to ride (via DB)")
sql = (
    f"UPDATE rides SET driver_id='{driver_db_id}', "
    f"status='driver_assigned', "
    f"driver_assigned_at=NOW() "
    f"WHERE id='{ride_id}';"
)
out = psql(sql)
check("DB update: driver_id + status=driver_assigned", "UPDATE 1" in out, out)

with httpx.Client(base_url=BASE, timeout=10) as c:
    r = c.get(f"/rides/{ride_id}", headers=ph)
    status = r.json().get("status", "")
    check("Ride status == driver_assigned (API)", status == "driver_assigned", status)

# ── 7. Status progression ─────────────────────────────────

section("7. Full status progression")
with httpx.Client(base_url=BASE, timeout=10) as c:
    for new_status in ["driver_en_route", "patient_picked_up",
                       "arrived_at_hospital", "completed"]:
        r = c.patch(f"/rides/{ride_id}/status",
                    json={"status": new_status}, headers=dh)
        check(f"  -> {new_status}", r.status_code == 200, r.text)

    r = c.get(f"/rides/{ride_id}", headers=ph)
    final = r.json().get("status", "")
    check("Final status = completed (patient view)", final == "completed", final)

# ── 8. Ride history ───────────────────────────────────────

section("8. Patient ride history")
with httpx.Client(base_url=BASE, timeout=10) as c:
    r = c.get("/rides/mine", headers=ph)
    check("GET /rides/mine -> 200", r.status_code == 200, r.text)
    body  = r.json()
    rides = body if isinstance(body, list) else body.get("rides", body.get("items", []))
    check("Completed ride in history", any(str(x.get("id")) == ride_id for x in rides))

# ── 9. WebSocket connectivity ─────────────────────────────

section("9. WebSocket connectivity")

async def test_ws():
    try:
        async with websockets.connect(
            f"{WS_BASE}/ws/driver/{ride_id}", open_timeout=5
        ) as ws:
            await ws.send(json.dumps({"token": driver_token}))
            await ws.send(json.dumps({"lat": 33.6844, "lng": 73.0479}))
            ok("Driver GPS WS: connect + send location")
    except Exception as e:
        fail("Driver GPS WS: connect + send location", str(e))

    try:
        async with websockets.connect(
            f"{WS_BASE}/ws/ride/{ride_id}", open_timeout=5
        ) as ws:
            await ws.send(json.dumps({"token": patient_token}))
            ok("Patient tracking WS: connect")
    except Exception as e:
        fail("Patient tracking WS: connect", str(e))

asyncio.run(test_ws())

# ── Summary ───────────────────────────────────────────────

section("Summary")
if errors:
    print(f"\n  {len(errors)} check(s) FAILED:")
    for e in errors:
        print(f"    * {e}")
    sys.exit(1)
else:
    print("\n  ALL CHECKS PASSED -- full ride flow verified end-to-end")
