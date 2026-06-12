"""
SmartRide NEMT — FastAPI Backend
Phase 1: Project scaffold with all core structure
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_fastapi_instrumentator import Instrumentator
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from sqlalchemy import text

import logging

from app.core.config import settings
from app.core.database import engine
from app.core.redis_client import ping_redis
from app.core.logging import StructuredLoggingMiddleware
from app.core.observability import init_error_tracking
from app.core.ratelimit import rate_limit_key
from app.routers import auth, patients, drivers, hospitals, rides, analytics, ws
from app.schemas.errors import ErrorResponse

log = logging.getLogger("smartride")

_WEAK_SECRET = "change_me_to_a_32_char_random_string_here"


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

    yield


# #2 Rate limiter shared across the app
limiter = Limiter(key_func=rate_limit_key, default_limits=["200/minute"])

app = FastAPI(
    title="SmartRide NEMT API",
    description="AI-Powered Emergency & Non-Emergency Medical Transportation",
    version="1.0.0",
    # #8 Hide interactive docs in production
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
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


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    # Force HTTPS for a year incl. subdomains — PHI must never travel cleartext.
    response.headers["Strict-Transport-Security"] = (
        "max-age=31536000; includeSubDomains"
    )
    # This is a JSON API; deny powerful browser features outright.
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    return response


Instrumentator(
    should_group_status_codes=True,
    should_ignore_untemplated=True,
).instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)


def _trace_id(request: Request) -> str | None:
    return getattr(request.state, "trace_id", None)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    first = exc.errors()[0] if exc.errors() else {}
    msg = first.get("msg", "Validation error")
    return JSONResponse(
        status_code=422,
        content=ErrorResponse(
            detail=msg, code="validation_error", trace_id=_trace_id(request)
        ).model_dump(),
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            detail=str(exc.detail), code="error", trace_id=_trace_id(request)
        ).model_dump(),
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # An unhandled exception is a 500. Without this it would vanish into a bare
    # stack trace; here we log it with the request's trace_id (Sentry, if
    # configured, captures it automatically) and hand the client that same
    # trace_id so support can correlate — but never leak the internal detail.
    trace_id = _trace_id(request)
    log.exception("Unhandled exception trace_id=%s path=%s", trace_id, request.url.path)
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            detail="Internal server error", code="internal_error", trace_id=trace_id
        ).model_dump(),
    )


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
        db_ok = False
    try:
        redis_ok = await ping_redis()
    except Exception:
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
