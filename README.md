# SmartRide NEMT

AI-Powered Emergency & Non-Emergency Medical Transportation platform for Pakistan (Islamabad/Rawalpindi pilot).

## Quick start

```bash
# 1. Copy env template and fill in your secrets
cp .env.example .env

# 2. Start all services
docker compose up --build
```

## Services

| Service | URL | Description |
|---|---|---|
| Backend API | http://localhost:8000 | FastAPI — main application |
| API Docs | http://localhost:8000/docs | Swagger UI |
| Triage AI | http://localhost:8001/docs | Symptom → specialty classifier |
| Admin Dashboard | http://localhost:3000 | Next.js control panel |
| PostgreSQL | localhost:5432 | Primary database (PostGIS) |
| Redis | localhost:6379 | Cache + Celery broker |

## Architecture

```
Patient/Driver Apps (Flutter)
         │
         ▼
   Backend API (FastAPI 8000)
    ├── Auth & CRUD
    ├── Emergency Dispatch ──► Triage AI (8001)
    ├── Hospital Matching
    ├── Notifications (Twilio / FHIR)
    └── WebSocket GPS tracking
         │
    PostgreSQL (PostGIS) + Redis
         │
   Admin Dashboard (Next.js 3000)
```

## Development milestones

| # | Feature | Status |
|---|---|---|
| 0 | Scaffold & tooling | ✅ |
| 1 | Database schema & API contract | pending |
| 2 | Auth & CRUD endpoints | pending |
| 3 | Hospital matching engine | pending |
| 4 | AI triage microservice | pending |
| 5 | Emergency dispatch pipeline | pending |
| 6 | Realtime GPS (WebSocket) | pending |
| 7 | Analytics & demand forecast | pending |
| 8 | Admin dashboard | pending |
| 9 | Flutter mobile apps | pending |
| 10 | Tests, load, CI/CD, deploy | pending |

## Env variables

See `.env.example` for all required variables.

Real secrets needed for full functionality:
- `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM_NUMBER` — SMS
- `GOOGLE_MAPS_API_KEY` — routing & maps
- `FIREBASE_PROJECT_ID` — push notifications

All external dependencies have graceful fallbacks so the core dispatch pipeline works without any API keys.
