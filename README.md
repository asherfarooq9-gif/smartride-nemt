# SmartRide NEMT

AI-Powered Emergency & Non-Emergency Medical Transportation platform for Pakistan (Islamabad/Rawalpindi pilot).

## Quick start (localhost)

```bash
# 1. Copy env template
cp .env.example .env          # Windows: copy .env.example .env

# 2. Build and start all services (first run takes ~5 min)
docker compose up --build -d

# 3. Seed admin user + demo hospitals
docker exec smartride_backend python seed.py

# 4. Open the admin dashboard
#    http://localhost:3000
#    Login: phone=+92300000001  password=admin123
```

### Common commands
```bash
make logs          # tail all service logs
make ps            # show running containers
make seed          # re-run seed script
make test          # run backend pytest suite locally
make shell-backend # bash inside the backend container
make down          # stop everything
make clean         # stop + remove volumes (fresh start)
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
| 9 | Flutter patient & driver apps (Riverpod + Dio, emergency flow, FCM) | ✅ |
| 10 | CI/CD (GitHub Actions), seed data, localhost docker-compose | ✅ |

## Milestone 9 — Flutter apps scope

**Patient app** (`apps/patient_app`): Riverpod + Dio (auth interceptor). Screens: splash → login/register → home (large red Emergency button + Book Ride) → symptom input (WCAG-AA quick-select + free text) → live tracking map (google_maps_flutter) → ride history. Emergency flow: capture GPS (geolocator) → POST /rides/emergency → poll GET /rides/{id} until driver assigned → open live map.

**Driver app** (`apps/driver_app`): Login → availability toggle (PATCH /drivers/status) → stream GPS to WebSocket → incoming ride card (accept/decline 30 s timer) → turn-by-turn navigation → status buttons (picked up / arrived / completed via PATCH /rides/{id}/status).

Both apps: FCM push notifications for ride status / new requests.

Done when: both apps compile (`flutter build apk --debug`) and the emergency flow works against the local backend.

Prerequisites (check before writing app code):
1. `flutter --version` — SDK must be present; if not, install from https://docs.flutter.dev/get-started/install
2. `flutter doctor -v` — Flutter SDK + Android toolchain + accepted licences must be green
3. Run target: connected device with USB debugging **or** a launched emulator

## Env variables

See `.env.example` for all required variables.

Real secrets needed for full functionality:
- `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM_NUMBER` — SMS
- `GOOGLE_MAPS_API_KEY` — routing & maps
- `FIREBASE_PROJECT_ID` — push notifications

All external dependencies have graceful fallbacks so the core dispatch pipeline works without any API keys.
