"""
SmartRide NEMT — FastAPI Backend
Phase 1: Project scaffold with all core structure
"""

import asyncio
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from prometheus_fastapi_instrumentator import Instrumentator
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
import asyncpg
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

import logging

from app.core.config import settings
from app.core.database import engine
from app.core.redis_client import close_redis, ping_redis
from app.core.logging import StructuredLoggingMiddleware
from app.core.observability import init_error_tracking
from app.core.ratelimit import make_limiter
from app.core.security import require_metrics_access
from app.routers import auth, patients, drivers, hospitals, rides, analytics, ws
from app.services import dispatch_loop
from app.services.ws_manager import location_manager
from app.schemas.errors import ErrorResponse

log = logging.getLogger("smartride")

_WEAK_SECRET = "change_me_to_a_32_char_random_string_here"


async def _stop_task(task: asyncio.Task, name: str) -> None:
    """Cancel a background task and wait for it so shutdown never leaves it half-run.

    gather() hands the task's CancelledError back as a value, while a cancellation
    aimed at this coroutine itself still propagates.
    """
    task.cancel()
    (result,) = await asyncio.gather(task, return_exceptions=True)
    if isinstance(result, Exception):
        log.error("%s crashed before shutdown", name, exc_info=result)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # #3 Fail fast if the default insecure secret key is still in use
    if settings.SECRET_KEY == _WEAK_SECRET:
        raise RuntimeError(
            "SECRET_KEY is still the default value. "
            'Generate a real key with: python -c "import secrets; print(secrets.token_hex(32))" '
            "and set it in your .env file."
        )

    if not settings.DEBUG and "*" in settings.ALLOWED_ORIGINS:
        import warnings

        warnings.warn(
            "ALLOWED_ORIGINS contains '*' in a non-DEBUG deployment. "
            "Set ALLOWED_ORIGINS in your .env to explicit origins.",
            stacklevel=2,
        )

    # Wire error tracking (no-op unless SENTRY_DSN is configured).
    init_error_tracking()

    dispatch_task = (
        asyncio.create_task(dispatch_loop.run_forever())
        if settings.DISPATCH_LOOP_ENABLED
        else None
    )
    try:
        yield
    finally:
        if dispatch_task:
            await _stop_task(dispatch_task, "dispatch loop")
        # Close pooled connections so a rolling deploy does not leave them dangling.
        await engine.dispose()
        await location_manager.close()
        await close_redis()


# #2 Rate limiter shared across the app
limiter = make_limiter(default_limits=["200/minute"])

app = FastAPI(
    title="SmartRide NEMT API",
    description="AI-Powered Emergency & Non-Emergency Medical Transportation",
    version="1.0.0",
    # #8 Hide interactive docs in production
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
    openapi_url="/openapi.json" if settings.DEBUG else None,
    lifespan=lifespan,
)

# #2 Attach rate-limiter middleware
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# #5 CORS: credentials=False is correct for Bearer-token auth (not cookies).
#    Wildcards with credentials=True are rejected by browsers and spec-invalid.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(StructuredLoggingMiddleware)


_SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    # Force HTTPS for a year incl. subdomains — PHI must never travel cleartext.
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    # This is a JSON API; deny powerful browser features outright.
    "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
}


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers.update(_SECURITY_HEADERS)
    return response


Instrumentator(
    should_group_status_codes=True,
    should_ignore_untemplated=True,
).instrument(app).expose(
    app,
    endpoint="/metrics",
    include_in_schema=False,
    dependencies=[Depends(require_metrics_access)],
)


def _trace_id(request: Request) -> str | None:
    return getattr(request.state, "trace_id", None)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # `detail` stays the first message (clients read it); `errors` adds the field
    # location of every problem so a form can highlight the right inputs.
    problems = [
        {
            "loc": list(err.get("loc", ())),
            "msg": err.get("msg", ""),
            "type": err.get("type", ""),
        }
        for err in exc.errors()
    ]
    msg = problems[0]["msg"] if problems else "Validation error"
    return JSONResponse(
        status_code=422,
        content={
            **ErrorResponse(
                detail=msg, code="validation_error", trace_id=_trace_id(request)
            ).model_dump(),
            "errors": problems,
        },
    )


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    # Registered for Starlette's class so router-level 404/405 share the envelope.
    # exc.headers carries WWW-Authenticate (401), Retry-After and Allow (405).
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            detail=str(exc.detail), code="error", trace_id=_trace_id(request)
        ).model_dump(),
        headers=exc.headers,
    )


@app.exception_handler(DBAPIError)
async def database_error_handler(request: Request, exc: DBAPIError):
    """Postgres refused the *value* (e.g. a NUL byte in text, a number out of range):
    that is the caller's input, not a server fault."""
    cause = getattr(exc.orig, "__cause__", None)
    if isinstance(cause, asyncpg.exceptions.DataError):
        return JSONResponse(
            status_code=422,
            content=ErrorResponse(
                detail="Invalid value in request",
                code="validation_error",
                trace_id=_trace_id(request),
            ).model_dump(),
        )
    return await unhandled_exception_handler(request, exc)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # An unhandled exception is a 500. Without this it would vanish into a bare
    # stack trace; here we log it with the request's trace_id (Sentry, if
    # configured, captures it automatically) and hand the client that same
    # trace_id so support can correlate — but never leak the internal detail.
    trace_id = _trace_id(request)
    log.exception("Unhandled exception trace_id=%s path=%s", trace_id, request.url.path)
    # This handler runs in Starlette's outermost layer, outside the CORS and
    # security-header middleware, so a 500 must carry those headers itself or a
    # browser reports an opaque CORS failure instead of the real error.
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            detail="Internal server error", code="internal_error", trace_id=trace_id
        ).model_dump(),
        headers={**_SECURITY_HEADERS, **_cors_headers(request)},
    )


def _cors_headers(request: Request) -> dict[str, str]:
    origin = request.headers.get("origin")
    if not origin:
        return {}
    if "*" in settings.ALLOWED_ORIGINS:
        return {"Access-Control-Allow-Origin": "*"}
    if origin in settings.ALLOWED_ORIGINS:
        return {"Access-Control-Allow-Origin": origin, "Vary": "Origin"}
    return {}


app.include_router(auth.router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(patients.router, prefix="/api/v1/patients", tags=["Patients"])
app.include_router(drivers.router, prefix="/api/v1/drivers", tags=["Drivers"])
app.include_router(hospitals.router, prefix="/api/v1/hospitals", tags=["Hospitals"])
app.include_router(rides.router, prefix="/api/v1/rides", tags=["Rides"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])
app.include_router(ws.router, prefix="/ws", tags=["WebSocket"])


@app.get("/health")
async def health():
    return {"status": "ok", "service": "SmartRide API", "version": "1.0.0"}


@app.get("/ready")
async def ready():
    db_ok = False
    redis_ok = False
    # Wrap the whole connection attempt: a pool/connection failure should report
    # "degraded" (503), never crash the endpoint with a 500.
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
            db_ok = True
    except Exception:
        log.warning("Readiness: database check failed", exc_info=True)
        db_ok = False
    try:
        redis_ok = await ping_redis()
    except Exception:
        log.warning("Readiness: redis check failed", exc_info=True)
        redis_ok = False
    status_code = 200 if (db_ok and redis_ok) else 503
    return JSONResponse(
        status_code=status_code,
        content={
            "status": "ready" if status_code == 200 else "degraded",
            "db": db_ok,
            "redis": redis_ok,
        },
    )
