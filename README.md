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
| 1 | Database schema & API contract | ✅ |
| 2 | Auth & CRUD endpoints | ✅ |
| 3 | Hospital matching engine | ✅ |
| 4 | AI triage microservice | ✅ |
| 5 | Emergency dispatch pipeline | ✅ |
| 6 | Realtime GPS (WebSocket) | ✅ |
| 7 | Analytics & demand forecast | ✅ |
| 8 | Admin dashboard | ✅ |
| 9 | Flutter patient & driver apps (Riverpod + Dio, emergency flow, FCM) | ✅ |
| 10 | CI/CD (GitHub Actions), seed data, localhost docker-compose | ✅ |

## Flutter apps

### Shared package — `packages/smartride_core`

Typed models, Dio API client (auth interceptor + 401→logout), WebSocket client (exponential backoff reconnect), `flutter_secure_storage` token storage, shared design tokens, validators, and reusable widgets. Both apps depend on this package via path.

### Patient app — `apps/patient_app`

| Screen | Description |
|--------|-------------|
| Login | Phone + password, JWT saved to secure storage |
| Home | Large Emergency button (72 dp, red), active ride banner, recent rides list |
| Symptoms | Quick-select chips + free text (max 2 000 chars) → POST /rides/emergency |
| Live Tracking | flutter_map (OpenStreetMap) — driver marker updated via WebSocket `/ws/ride/{id}` |
| Ride Detail | Status badge, timeline, "Track Live" for active rides |
| Ride History | Paginated list |
| Profile | Card view + edit form (name, DOB, mobility needs, emergency contact) |
| Settings | Account, Support, About, Sign Out |

### Driver app — `apps/driver_app`

| Screen | Description |
|--------|-------------|
| Login | Phone + password; rejects non-driver JWT |
| Dashboard | Online/offline toggle, pending ride cards with 30 s countdown (red ≤ 10 s), auto-refresh |
| Active Ride | Status progression buttons, flutter_map showing patient pin, cancel flow |
| Profile | Driver info + edit |
| Settings | Notification toggles (persisted), Sign Out |

GPS streaming (`GpsStreamNotifier`): on accept, connects WebSocket `/ws/driver/{id}`, sends `{"token": jwt}` first, then streams `{"lat", "lng"}` from `geolocator` every 10 m. REST fallback `PATCH /drivers/location` throttled to 1/5 s.

### FCM setup

Each app requires a `google-services.json` in `android/app/`. Register both package names in Firebase console:
- Patient: `com.smartride.patient_app`
- Driver: `com.smartride.driver_app`

### Run the apps

```bash
# Copy env template (Android emulator default — points to host backend)
cp apps/patient_app/.env.example apps/patient_app/.env
cp apps/driver_app/.env.example apps/driver_app/.env

# Install dependencies
cd apps/patient_app && flutter pub get
cd ../driver_app && flutter pub get

# Run (with emulator or USB device connected)
cd apps/patient_app && flutter run
cd ../driver_app && flutter run
```

### Build release APK

```bash
flutter build apk --debug    # debug (no signing needed)
flutter build apk --release  # release (requires signing config)
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

## Env variables

See `.env.example` for all required variables.

Real secrets needed for full functionality:
- `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM_NUMBER` — SMS
- `FIREBASE_PROJECT_ID` — push notifications (Flutter apps use `google-services.json`, not an env var)

Maps use OpenStreetMap via `flutter_map` — no API key required.

All external dependencies have graceful fallbacks so the core dispatch pipeline works without any API keys.
