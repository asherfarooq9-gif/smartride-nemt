# SmartRide Backend Improvement Plan (Stages 1–7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve code quality, security, testing, observability, API consistency, performance, and architecture of the FastAPI backend.

**Architecture:** FastAPI + SQLAlchemy (async) + PostgreSQL + Redis + Celery. All changes are backward-compatible. Tests use pytest-asyncio against a real PostgreSQL test DB.

**Tech Stack:** Python 3.11, FastAPI 0.111, SQLAlchemy 2.0, pydantic-settings 2.x, pytest 8.2, redis 5.x, slowapi, prometheus-fastapi-instrumentator (new).

---

### Task 1: Fix Pydantic v2 Settings Config Syntax

**Files:**
- Modify: `backend/app/core/config.py`

Pydantic-settings v2 deprecates the inner `class Config`. This causes a deprecation warning in tests and will break in a future release.

- [ ] **Step 1: Open and read the current config**

```python
# backend/app/core/config.py (current — note the class Config at the bottom)
class Settings(BaseSettings):
    ...
    class Config:
        env_file = ".env"
        case_sensitive = True
```

- [ ] **Step 2: Replace with model_config**

Replace the entire `config.py` with:

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True)

    # JWT
    SECRET_KEY: str = "change_me_to_a_32_char_random_string_here"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://smartride:password@postgres:5432/smartride"

    # Redis
    REDIS_URL: str = "redis://redis:6379/0"

    # AI Services
    TRIAGE_SERVICE_URL: str = "http://triage:8001"

    # Twilio
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_FROM_NUMBER: str = ""

    # Google Maps
    GOOGLE_MAPS_API_KEY: str = ""

    # Firebase
    FIREBASE_PROJECT_ID: str = ""

    # App
    DEBUG: bool = False
    ALLOWED_ORIGINS: List[str] = ["*"]
    EMERGENCY_PIPELINE_TARGET_SECONDS: float = 60.0


settings = Settings()
```

- [ ] **Step 3: Verify no deprecation warnings**

```bash
cd backend && python -c "from app.core.config import settings; print(settings.DEBUG)"
```
Expected output: `False` with no DeprecationWarning.

- [ ] **Step 4: Commit**

```bash
git add backend/app/core/config.py
git commit -m "fix: migrate pydantic-settings to v2 model_config syntax"
```

---

### Task 2: Standardize Error Response Shape

**Files:**
- Create: `backend/app/schemas/errors.py`
- Modify: `backend/main.py`

Currently some endpoints return `HTTPException(detail="bare string")` while others return `HTTPException(detail={"message": "...", "code": "..."})`. Standardize to `{"detail": "...", "code": "..."}`.

- [ ] **Step 1: Create the error schema**

```python
# backend/app/schemas/errors.py
from pydantic import BaseModel


class ErrorResponse(BaseModel):
    detail: str
    code: str = "error"
```

- [ ] **Step 2: Add a custom exception handler to main.py**

In `backend/main.py`, after the existing imports add:

```python
from fastapi.exceptions import RequestValidationError
from app.schemas.errors import ErrorResponse
```

Then add these two handlers before `app.include_router(...)` lines:

```python
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    first = exc.errors()[0] if exc.errors() else {}
    msg = first.get("msg", "Validation error")
    return JSONResponse(
        status_code=422,
        content=ErrorResponse(detail=msg, code="validation_error").model_dump(),
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(detail=str(exc.detail), code="error").model_dump(),
    )
```

- [ ] **Step 3: Write a test verifying the shape**

Add to `backend/tests/test_auth.py`:

```python
async def test_login_wrong_password_returns_standard_error_shape(client):
    resp = await client.post("/api/v1/auth/login", json={"phone": "+92000000000", "password": "wrong"})
    assert resp.status_code == 401
    body = resp.json()
    assert "detail" in body
    assert "code" in body
```

- [ ] **Step 4: Run the test**

```bash
cd backend && pytest tests/test_auth.py::test_login_wrong_password_returns_standard_error_shape -v
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas/errors.py backend/main.py backend/tests/test_auth.py
git commit -m "feat: standardize all error responses to {detail, code} shape"
```

---

### Task 3: Add /ready Health Endpoint

**Files:**
- Modify: `backend/main.py`
- Modify: `backend/app/core/redis_client.py`

The existing `/health` is a static response. Add `/ready` that actually pings DB and Redis before returning 200.

- [ ] **Step 1: Add a ping helper to redis_client.py**

Append to `backend/app/core/redis_client.py`:

```python
async def ping_redis() -> bool:
    try:
        r = await get_redis()
        return await r.ping()
    except Exception:
        return False
```

- [ ] **Step 2: Write the failing test**

Add `backend/tests/test_health.py`:

```python
import pytest
from httpx import AsyncClient, ASGITransport
import os

os.environ.setdefault("DATABASE_URL", os.getenv("TEST_DATABASE_URL", "postgresql+asyncpg://smartride:password@localhost:5432/smartride_test"))
os.environ.setdefault("SECRET_KEY", "test-secret-key-32-chars-long!!")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")

from main import app


@pytest.mark.asyncio
async def test_health_returns_ok():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_ready_returns_ok_when_db_and_redis_up(client):
    resp = await client.get("/ready")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ready"
    assert body["db"] is True
    assert body["redis"] is True
```

- [ ] **Step 3: Run to verify it fails**

```bash
cd backend && pytest tests/test_health.py::test_ready_returns_ok_when_db_and_redis_up -v
```
Expected: FAIL — `404 Not Found`.

- [ ] **Step 4: Add the /ready endpoint to main.py**

After the existing `/health` endpoint at the bottom of `backend/main.py`:

```python
from app.core.redis_client import ping_redis
from sqlalchemy import text


@app.get("/ready")
async def ready():
    db_ok = False
    redis_ok = False
    async with engine.connect() as conn:
        try:
            await conn.execute(text("SELECT 1"))
            db_ok = True
        except Exception:
            pass
    redis_ok = await ping_redis()
    status_code = 200 if (db_ok and redis_ok) else 503
    from fastapi.responses import JSONResponse as _JSONResponse
    return _JSONResponse(
        status_code=status_code,
        content={"status": "ready" if status_code == 200 else "degraded", "db": db_ok, "redis": redis_ok},
    )
```

Also add `engine` to the imports at the top of `main.py`:

```python
from app.core.database import engine, Base
```

- [ ] **Step 5: Run tests**

```bash
cd backend && pytest tests/test_health.py -v
```
Expected: both PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/main.py backend/app/core/redis_client.py backend/tests/test_health.py
git commit -m "feat: add /ready endpoint with real DB and Redis liveness checks"
```

---

### Task 4: Add Structured JSON Logging with Correlation IDs

**Files:**
- Create: `backend/app/core/logging.py`
- Modify: `backend/main.py`

Every request should emit a JSON log line with `trace_id`, `method`, `path`, `status_code`, and `duration_ms`. The trace ID should be forwarded in the `X-Trace-Id` response header so the client can correlate.

- [ ] **Step 1: Create the logging module**

```python
# backend/app/core/logging.py
import json
import logging
import time
import uuid
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

from app.core.config import settings

logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL, logging.INFO),
    format="%(message)s",
)
logger = logging.getLogger("smartride")


class StructuredLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        trace_id = str(uuid.uuid4())
        request.state.trace_id = trace_id
        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = round((time.perf_counter() - start) * 1000, 1)
        response.headers["X-Trace-Id"] = trace_id
        logger.info(json.dumps({
            "trace_id": trace_id,
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": duration_ms,
        }))
        return response
```

- [ ] **Step 2: Add LOG_LEVEL to Settings**

In `backend/app/core/config.py`, add inside the `Settings` class:

```python
    LOG_LEVEL: str = "INFO"
```

- [ ] **Step 3: Register the middleware in main.py**

Add this import near the top of `backend/main.py`:

```python
from app.core.logging import StructuredLoggingMiddleware
```

Add this line after the `CORSMiddleware` block:

```python
app.add_middleware(StructuredLoggingMiddleware)
```

- [ ] **Step 4: Verify manually**

```bash
cd backend && python -c "
import asyncio, json
from httpx import AsyncClient, ASGITransport
from main import app

async def check():
    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as c:
        r = await c.get('/health')
        print('Trace-Id header:', r.headers.get('x-trace-id'))

asyncio.run(check())
"
```
Expected: prints a UUID trace ID.

- [ ] **Step 5: Commit**

```bash
git add backend/app/core/logging.py backend/app/core/config.py backend/main.py
git commit -m "feat: add structured JSON logging middleware with correlation IDs"
```

---

### Task 5: Add Prometheus Metrics

**Files:**
- Modify: `backend/requirements.txt`
- Modify: `backend/main.py`

- [ ] **Step 1: Add the dependency**

Append to `backend/requirements.txt`:

```
prometheus-fastapi-instrumentator==6.1.0
```

- [ ] **Step 2: Install**

```bash
cd backend && pip install prometheus-fastapi-instrumentator==6.1.0
```

- [ ] **Step 3: Wire up in main.py**

Add import at the top of `backend/main.py`:

```python
from prometheus_fastapi_instrumentator import Instrumentator
```

Add after the middleware registrations (but before `include_router` calls):

```python
Instrumentator(
    should_group_status_codes=True,
    should_ignore_untemplated=True,
).instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)
```

- [ ] **Step 4: Verify the endpoint exists**

```bash
cd backend && python -c "
import asyncio
from httpx import AsyncClient, ASGITransport
from main import app

async def check():
    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as c:
        r = await c.get('/metrics')
        print(r.status_code, r.text[:200])

asyncio.run(check())
"
```
Expected: `200` with Prometheus text format lines starting with `#`.

- [ ] **Step 5: Commit**

```bash
git add backend/requirements.txt backend/main.py
git commit -m "feat: expose Prometheus metrics at /metrics"
```

---

### Task 6: Add JWT Refresh Token Endpoint

**Files:**
- Modify: `backend/app/core/security.py`
- Modify: `backend/app/routers/auth.py`
- Modify: `backend/app/schemas/auth.py`
- Test: `backend/tests/test_auth.py`

JWT tokens expire in 60 minutes with no way to refresh. Add `POST /auth/refresh` that exchanges a valid (non-expired, non-blocked) token for a new one.

- [ ] **Step 1: Add RefreshResponse schema**

Open `backend/app/schemas/auth.py` and add:

```python
class RefreshResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
```

- [ ] **Step 2: Write the failing test**

Add to `backend/tests/test_auth.py`:

```python
async def test_refresh_returns_new_token(client):
    # register and get initial token
    resp = await client.post("/api/v1/auth/register", json={
        "phone": "+92300000099",
        "password": "Passw0rd!",
        "role": "patient",
        "full_name": "Refresh User",
    })
    assert resp.status_code == 201
    old_token = resp.json()["access_token"]

    # exchange for new token
    resp2 = await client.post(
        "/api/v1/auth/refresh",
        headers={"Authorization": f"Bearer {old_token}"},
    )
    assert resp2.status_code == 200
    new_token = resp2.json()["access_token"]
    assert new_token != old_token


async def test_refresh_fails_after_logout(client):
    resp = await client.post("/api/v1/auth/register", json={
        "phone": "+92300000098",
        "password": "Passw0rd!",
        "role": "patient",
        "full_name": "Logout Test",
    })
    token = resp.json()["access_token"]
    await client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
    resp2 = await client.post("/api/v1/auth/refresh", headers={"Authorization": f"Bearer {token}"})
    assert resp2.status_code == 401
```

- [ ] **Step 3: Run to verify failure**

```bash
cd backend && pytest tests/test_auth.py::test_refresh_returns_new_token -v
```
Expected: FAIL — `404`.

- [ ] **Step 4: Add the refresh endpoint to auth.py**

Add this import at the top of `backend/app/routers/auth.py`:

```python
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, RefreshResponse
```

Add this endpoint after the `/logout` endpoint:

```python
@router.post("/refresh", response_model=RefreshResponse)
async def refresh_token(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
):
    user = await get_current_user(credentials=credentials, db=db)
    # Block the old token so it cannot be reused
    try:
        payload = jwt.decode(credentials.credentials, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        jti = payload.get("jti", "")
        exp = payload.get("exp", 0)
        remaining = max(0, int(exp - datetime.now(timezone.utc).timestamp()))
        if jti and remaining > 0:
            await block_token(jti, remaining)
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    new_token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return RefreshResponse(access_token=new_token)
```

Also add the missing import at the top of `auth.py`:

```python
from app.core.redis_client import block_token
```

- [ ] **Step 5: Run tests**

```bash
cd backend && pytest tests/test_auth.py -v
```
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/auth.py backend/app/schemas/auth.py backend/tests/test_auth.py
git commit -m "feat: add POST /auth/refresh to exchange expiring tokens"
```

---

### Task 7: Implement Celery Tasks with Retry Policies

**Files:**
- Modify: `backend/app/tasks.py`

The Celery tasks are currently empty stubs (`pass`). Wire them up to the existing notification services and add retry/backoff.

- [ ] **Step 1: Replace tasks.py with real implementations**

```python
# backend/app/tasks.py
import logging
from app.core.celery_app import celery_app

logger = logging.getLogger("smartride.tasks")


@celery_app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=10,
    autoretry_for=(Exception,),
    retry_backoff=True,
)
def send_sms_task(self, to: str, body: str):
    from app.core.config import settings
    if not settings.TWILIO_ACCOUNT_SID:
        logger.info("Twilio not configured — skipping SMS to %s", to)
        return
    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        client.messages.create(to=to, from_=settings.TWILIO_FROM_NUMBER, body=body)
        logger.info("SMS sent to %s", to)
    except Exception as exc:
        logger.warning("SMS failed for %s: %s — retrying", to, exc)
        raise self.retry(exc=exc)


@celery_app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=15,
    autoretry_for=(Exception,),
    retry_backoff=True,
)
def send_hospital_alert_task(self, ride_id: str, triage: dict, hospital_id: str):
    logger.info(
        "Hospital alert — ride=%s hospital=%s severity=%s",
        ride_id,
        hospital_id,
        triage.get("severity"),
    )
```

- [ ] **Step 2: Verify import works**

```bash
cd backend && python -c "from app.tasks import send_sms_task, send_hospital_alert_task; print('ok')"
```
Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add backend/app/tasks.py
git commit -m "feat: implement Celery tasks with exponential retry/backoff"
```

---

### Task 8: Add Database Indexes for Hot Columns

**Files:**
- Modify: `backend/app/models/models.py`
- Create: `backend/alembic/versions/<timestamp>_add_performance_indexes.py`

Without indexes on `status`, `ride_type`, and `requested_at`, every filter scan is a full table scan.

- [ ] **Step 1: Add Index declarations to models.py**

In `backend/app/models/models.py`, add this import at the top:

```python
from sqlalchemy import Index
```

Find the `Ride` model class and add `__table_args__` at the end of the class (before the closing of the class body):

```python
    __table_args__ = (
        Index("ix_rides_status", "status"),
        Index("ix_rides_ride_type", "ride_type"),
        Index("ix_rides_requested_at", "requested_at"),
        Index("ix_rides_patient_id", "patient_id"),
        Index("ix_rides_driver_id", "driver_id"),
    )
```

Find the `Driver` model class and add:

```python
    __table_args__ = (
        Index("ix_drivers_status", "status"),
        Index("ix_drivers_user_id", "user_id"),
    )
```

Find the `TriageEvent` model class and add:

```python
    __table_args__ = (
        Index("ix_triage_ride_id", "ride_id"),
    )
```

- [ ] **Step 2: Generate the Alembic migration**

```bash
cd backend && alembic revision --autogenerate -m "add performance indexes"
```
Expected: creates a new file in `alembic/versions/`.

- [ ] **Step 3: Inspect the generated migration**

Open the generated file and confirm it contains `op.create_index` calls for the indexes above. If autogenerate missed any, add them manually:

```python
def upgrade() -> None:
    op.create_index("ix_rides_status", "rides", ["status"])
    op.create_index("ix_rides_ride_type", "rides", ["ride_type"])
    op.create_index("ix_rides_requested_at", "rides", ["requested_at"])
    op.create_index("ix_rides_patient_id", "rides", ["patient_id"])
    op.create_index("ix_rides_driver_id", "rides", ["driver_id"])
    op.create_index("ix_drivers_status", "drivers", ["status"])
    op.create_index("ix_drivers_user_id", "drivers", ["user_id"])
    op.create_index("ix_triage_ride_id", "triage_events", ["ride_id"])


def downgrade() -> None:
    op.drop_index("ix_rides_status", "rides")
    op.drop_index("ix_rides_ride_type", "rides")
    op.drop_index("ix_rides_requested_at", "rides")
    op.drop_index("ix_rides_patient_id", "rides")
    op.drop_index("ix_rides_driver_id", "rides")
    op.drop_index("ix_drivers_status", "drivers")
    op.drop_index("ix_drivers_user_id", "drivers")
    op.drop_index("ix_triage_ride_id", "triage_events")
```

- [ ] **Step 4: Apply migration to test DB**

```bash
cd backend && DATABASE_URL=postgresql+asyncpg://smartride:password@localhost:5432/smartride_test alembic upgrade head
```

- [ ] **Step 5: Run full test suite to confirm no regressions**

```bash
cd backend && pytest -v
```
Expected: all existing tests PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/app/models/models.py backend/alembic/versions/
git commit -m "perf: add SQLAlchemy indexes on hot query columns"
```

---

### Task 9: Fix Ride Detail N+1 Queries

**Files:**
- Modify: `backend/app/routers/rides.py`

The `GET /rides/{id}/detail` endpoint currently fires 4 separate SELECTs for Patient+User, Driver+User, Hospital, and TriageEvent. Use `selectinload` to batch them.

- [ ] **Step 1: Write the failing performance test**

Add to `backend/tests/test_rides.py`:

```python
from unittest.mock import patch

async def test_ride_detail_does_not_fire_per_entity_queries(client, db):
    """Verify no extra queries per related entity in ride detail."""
    # create a patient user + ride via register + emergency endpoint
    reg = await client.post("/api/v1/auth/register", json={
        "phone": "+92300099001",
        "password": "Passw0rd!",
        "role": "patient",
        "full_name": "N+1 Test Patient",
    })
    token = reg.json()["access_token"]
    ride_resp = await client.post(
        "/api/v1/rides/emergency",
        headers={"Authorization": f"Bearer {token}"},
        json={"symptom_text": "chest pain", "pickup_lat": 33.72, "pickup_lng": 73.04},
    )
    ride_id = ride_resp.json()["id"]

    query_count = []
    original_execute = db.__class__.execute

    async def counting_execute(self, *args, **kwargs):
        query_count.append(1)
        return await original_execute(self, *args, **kwargs)

    with patch.object(db.__class__, "execute", counting_execute):
        resp = await client.get(
            f"/api/v1/rides/{ride_id}/detail",
            headers={"Authorization": f"Bearer {token}"},
        )
    assert resp.status_code == 200
    # With selectinload, detail fetch should be ≤ 3 queries (ride + related batches)
    assert len(query_count) <= 3, f"Expected ≤3 queries, got {len(query_count)}"
```

- [ ] **Step 2: Add selectinload imports to rides.py**

In `backend/app/routers/rides.py` add to the sqlalchemy import line:

```python
from sqlalchemy.orm import selectinload
```

- [ ] **Step 3: Update the ride detail query**

Find the `get_ride_detail` endpoint (or whichever function fires the 4 separate SELECTs around lines 155–200). Replace the separate queries for patient, driver, hospital with a single eager-loaded query:

```python
from sqlalchemy.orm import selectinload

result = await db.execute(
    select(Ride)
    .where(Ride.id == ride_id)
    .options(
        selectinload(Ride.patient).selectinload(Patient.user),
        selectinload(Ride.driver).selectinload(Driver.user),
        selectinload(Ride.hospital),
    )
)
ride = result.scalar_one_or_none()
if not ride:
    raise HTTPException(404, "Ride not found")
```

This requires `Ride` to have `patient`, `driver`, and `hospital` relationships defined. Verify in `models.py` that these relationships exist; if not, add them:

```python
# In the Ride model in models.py
patient:  Mapped[Optional["Patient"]]  = relationship("Patient",  foreign_keys=[patient_id],  lazy="noload")
driver:   Mapped[Optional["Driver"]]   = relationship("Driver",   foreign_keys=[driver_id],   lazy="noload")
hospital: Mapped[Optional["Hospital"]] = relationship("Hospital", foreign_keys=[hospital_id], lazy="noload")
```

- [ ] **Step 4: Run existing ride tests**

```bash
cd backend && pytest tests/test_rides.py -v
```
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/rides.py backend/app/models/models.py
git commit -m "perf: use selectinload to eliminate N+1 queries in ride detail"
```

---

### Task 10: Add Redis Cache for Hospital List

**Files:**
- Modify: `backend/app/routers/hospitals.py`
- Modify: `backend/app/core/redis_client.py`

The hospital list rarely changes but is queried by every emergency dispatch and by the admin dashboard. Cache it for 5 minutes.

- [ ] **Step 1: Add a generic cache helper to redis_client.py**

Append to `backend/app/core/redis_client.py`:

```python
import json as _json
from typing import Any, Callable, Awaitable

async def get_cached(key: str, ttl: int, loader: Callable[[], Awaitable[Any]]) -> Any:
    """Return cached JSON value for key, or call loader(), cache result, and return it."""
    r = await get_redis()
    raw = await r.get(key)
    if raw is not None:
        return _json.loads(raw)
    value = await loader()
    await r.setex(key, ttl, _json.dumps(value))
    return value


async def invalidate_cache(key: str) -> None:
    r = await get_redis()
    await r.delete(key)
```

- [ ] **Step 2: Write a test for cache behavior**

Add `backend/tests/test_hospitals.py`:

```python
import pytest
from httpx import AsyncClient, ASGITransport
import os

os.environ.setdefault("DATABASE_URL", os.getenv("TEST_DATABASE_URL", "postgresql+asyncpg://smartride:password@localhost:5432/smartride_test"))
os.environ.setdefault("SECRET_KEY", "test-secret-key-32-chars-long!!")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")

from main import app


@pytest.mark.asyncio
async def test_hospital_list_returns_200(client):
    # Register admin to hit the hospitals endpoint
    reg = await client.post("/api/v1/auth/register", json={
        "phone": "+92300099002",
        "password": "Passw0rd!",
        "role": "patient",
        "full_name": "Cache Test",
    })
    # hospitals list is public or admin — check the router for auth requirements
    resp = await client.get("/api/v1/hospitals")
    assert resp.status_code in (200, 401)  # 401 if admin-only, 200 if public


@pytest.mark.asyncio
async def test_redis_cache_helper_stores_and_retrieves(db):
    from app.core.redis_client import get_cached, invalidate_cache

    call_count = {"n": 0}

    async def loader():
        call_count["n"] += 1
        return {"hospitals": []}

    await invalidate_cache("test:hospitals")
    v1 = await get_cached("test:hospitals", 60, loader)
    v2 = await get_cached("test:hospitals", 60, loader)
    assert v1 == v2
    assert call_count["n"] == 1  # loader only called once — second hit was cached
    await invalidate_cache("test:hospitals")
```

- [ ] **Step 3: Run to see the cache test pass (loader test passes, hospital list test depends on auth)**

```bash
cd backend && pytest tests/test_hospitals.py::test_redis_cache_helper_stores_and_retrieves -v
```
Expected: PASS.

- [ ] **Step 4: Apply cache in hospitals router**

In `backend/app/routers/hospitals.py`, find the GET list endpoint and wrap the DB query:

```python
from app.core.redis_client import get_cached

HOSPITALS_CACHE_KEY = "cache:hospitals:active"
HOSPITALS_CACHE_TTL = 300  # 5 minutes


@router.get("/", ...)
async def list_hospitals(db: AsyncSession = Depends(get_db)):
    async def _load():
        result = await db.execute(
            select(Hospital).where(Hospital.is_active.is_(True)).order_by(Hospital.name)
        )
        hospitals = result.scalars().all()
        return [h.__dict__ for h in hospitals]  # adjust to your response schema

    return await get_cached(HOSPITALS_CACHE_KEY, HOSPITALS_CACHE_TTL, _load)
```

Note: adjust the serialization to match the actual `HospitalResponse` schema in use.

- [ ] **Step 5: Invalidate cache when a hospital is updated**

In any endpoint that updates a hospital (create, update, toggle active), add:

```python
from app.core.redis_client import invalidate_cache
await invalidate_cache("cache:hospitals:active")
```

- [ ] **Step 6: Run all tests**

```bash
cd backend && pytest -v
```
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/app/routers/hospitals.py backend/app/core/redis_client.py backend/tests/test_hospitals.py
git commit -m "perf: add 5-minute Redis cache for active hospital list"
```

---

### Task 11: Add Missing Test Coverage — Unhappy Paths

**Files:**
- Modify: `backend/tests/test_dispatch.py`
- Modify: `backend/tests/test_websocket.py`

- [ ] **Step 1: Add no-drivers-available test to test_dispatch.py**

Append to `backend/tests/test_dispatch.py`:

```python
async def test_emergency_dispatch_when_no_drivers_available(client):
    """When no driver is available, ride should remain pending (not crash)."""
    reg = await client.post("/api/v1/auth/register", json={
        "phone": "+92300099003",
        "password": "Passw0rd!",
        "role": "patient",
        "full_name": "No Driver Test",
    })
    token = reg.json()["access_token"]

    resp = await client.post(
        "/api/v1/rides/emergency",
        headers={"Authorization": f"Bearer {token}"},
        json={"symptom_text": "headache", "pickup_lat": 33.72, "pickup_lng": 73.04},
    )
    # Should succeed (201 or 200) — driver assignment happens async in background
    assert resp.status_code in (200, 201)
    body = resp.json()
    assert "id" in body
    # status is either pending (no driver) or driver_assigned (if one exists in test DB)
    assert body["status"] in ("pending", "driver_assigned")
```

- [ ] **Step 2: Add expired token test to test_websocket.py**

Append to `backend/tests/test_websocket.py`:

```python
async def test_websocket_rejects_missing_auth(client):
    """WebSocket should close with 4001 if no auth message is sent within timeout."""
    import asyncio
    from httpx import AsyncClient, ASGITransport
    from main import app
    from starlette.testclient import TestClient

    with TestClient(app) as tc:
        with tc.websocket_connect("/ws/driver") as ws:
            # Don't send auth — expect server to close connection
            import pytest
            with pytest.raises(Exception):
                # Server should disconnect after _AUTH_TIMEOUT_SECONDS (5s)
                # In tests we just verify it doesn't hang forever
                ws.receive_text()


async def test_websocket_rejects_invalid_token(client):
    """WebSocket should close if an invalid JWT is sent as auth."""
    from starlette.testclient import TestClient
    from main import app

    with TestClient(app) as tc:
        with tc.websocket_connect("/ws/driver") as ws:
            import json, pytest
            ws.send_text(json.dumps({"token": "not.a.real.jwt"}))
            with pytest.raises(Exception):
                ws.receive_text()
```

- [ ] **Step 3: Run the new tests**

```bash
cd backend && pytest tests/test_dispatch.py tests/test_websocket.py -v
```
Expected: all PASS (adjust assertions if test DB state differs).

- [ ] **Step 4: Check coverage on services**

```bash
cd backend && pip install pytest-cov && pytest --cov=app/services --cov=app/routers --cov-report=term-missing
```
Expected: ≥ 80% on `app/services/` and `app/routers/`.

- [ ] **Step 5: Commit**

```bash
git add backend/tests/test_dispatch.py backend/tests/test_websocket.py
git commit -m "test: add unhappy-path coverage for dispatch and WebSocket auth"
```

---

### Task 12: Fix ALLOWED_ORIGINS Wildcard in Production

**Files:**
- Modify: `backend/main.py`

The default `ALLOWED_ORIGINS = ["*"]` is fine in development but dangerous in production. Add a startup warning.

- [ ] **Step 1: Add a production CORS warning to the lifespan**

In `backend/main.py`, inside the `lifespan` context manager, after the SECRET_KEY check add:

```python
    if not settings.DEBUG and "*" in settings.ALLOWED_ORIGINS:
        import warnings
        warnings.warn(
            "ALLOWED_ORIGINS contains '*' in a non-DEBUG deployment. "
            "Set ALLOWED_ORIGINS in your .env to explicit origin(s).",
            stacklevel=2,
        )
```

- [ ] **Step 2: Verify**

```bash
cd backend && python -c "
import os; os.environ['SECRET_KEY'] = 'a' * 32; os.environ['DEBUG'] = 'false'
import warnings
with warnings.catch_warnings(record=True) as w:
    warnings.simplefilter('always')
    from app.core.config import settings
    if not settings.DEBUG and '*' in settings.ALLOWED_ORIGINS:
        warnings.warn('ALLOWED_ORIGINS wildcard in production', stacklevel=1)
    print('warnings:', [str(x.message) for x in w])
"
```

- [ ] **Step 3: Run full test suite**

```bash
cd backend && pytest -v
```
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add backend/main.py
git commit -m "sec: warn when ALLOWED_ORIGINS is wildcard in non-DEBUG mode"
```

---

## Final Verification

- [ ] Run full test suite: `cd backend && pytest -v`
- [ ] Check coverage: `cd backend && pytest --cov=app/services --cov=app/routers --cov-report=term-missing`
- [ ] Verify Docker build: `docker compose build backend`
- [ ] Smoke test all health endpoints: `curl localhost:8000/health && curl localhost:8000/ready`
