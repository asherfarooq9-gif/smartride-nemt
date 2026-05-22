"""
SmartRide NEMT — FastAPI Backend
Phase 1: Project scaffold with all core structure
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.database import engine, Base
from app.routers import auth, patients, drivers, hospitals, rides, analytics, ws


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown — nothing needed


app = FastAPI(
    title="SmartRide NEMT API",
    description="AI-Powered Emergency & Non-Emergency Medical Transportation",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,      prefix="/api/v1/auth",      tags=["Auth"])
app.include_router(patients.router,  prefix="/api/v1/patients",  tags=["Patients"])
app.include_router(drivers.router,   prefix="/api/v1/drivers",   tags=["Drivers"])
app.include_router(hospitals.router, prefix="/api/v1/hospitals", tags=["Hospitals"])
app.include_router(rides.router,     prefix="/api/v1/rides",     tags=["Rides"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])
app.include_router(ws.router,        prefix="/ws",              tags=["WebSocket"])


@app.get("/health")
async def health():
    return {"status": "ok", "service": "SmartRide API", "version": "1.0.0"}
