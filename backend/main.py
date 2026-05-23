"""
SmartRide NEMT — FastAPI Backend
Phase 1: Project scaffold with all core structure
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address

from app.core.config import settings
from app.core.database import engine, Base
from app.routers import auth, patients, drivers, hospitals, rides, analytics, ws

_WEAK_SECRET = "change_me_to_a_32_char_random_string_here"


@asynccontextmanager
async def lifespan(app: FastAPI):
    # #3 Fail fast if the default insecure secret key is still in use
    if settings.SECRET_KEY == _WEAK_SECRET:
        raise RuntimeError(
            "SECRET_KEY is still the default value. "
            "Generate a real key with: python -c \"import secrets; print(secrets.token_hex(32))\" "
            "and set it in your .env file."
        )

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


# #2 Rate limiter shared across the app
limiter = Limiter(key_func=get_remote_address, default_limits=["200/minute"])

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

app.include_router(auth.router,      prefix="/api/v1/auth",      tags=["Auth"])
app.include_router(patients.router,  prefix="/api/v1/patients",  tags=["Patients"])
app.include_router(drivers.router,   prefix="/api/v1/drivers",   tags=["Drivers"])
app.include_router(hospitals.router, prefix="/api/v1/hospitals", tags=["Hospitals"])
app.include_router(rides.router,     prefix="/api/v1/rides",     tags=["Rides"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])
app.include_router(ws.router,        prefix="/ws",               tags=["WebSocket"])


@app.get("/health")
async def health():
    return {"status": "ok", "service": "SmartRide API", "version": "1.0.0"}
