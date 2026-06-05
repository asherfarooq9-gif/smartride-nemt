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
| 11 | Multi-role auth (patient+driver in one account), unified SmartRide app | ✅ |
| 12 | Driver dispatch endpoints, verification gating, security hardening | ✅ |

## Flutter app

One unified app (`apps/patient_app`) — patients and drivers in the same install. Sign up as **Patient**, **Driver**, or **Both**. Switch portals any time from the drawer.

### Shared package — `packages/smartride_core`

Typed models, Dio API client (auth interceptor + 401→logout), WebSocket client (exponential backoff reconnect), `flutter_secure_storage` token storage, shared design tokens, validators, and reusable widgets.

### Unified SmartRide app — `apps/patient_app`

#### Auth flow
| Screen | Description |
|--------|-------------|
| Welcome | Entry point — Log In or Sign Up |
| Sign Up | Choose role: Patient / Driver / Both. Driver fields shown conditionally |
| Log In | Phone + password; multi-role JWT stored securely |
| Become a Driver/Patient | Add a second role to an existing account |

#### Patient portal (blue theme)
| Screen | Description |
|--------|-------------|
| Home | Large Emergency button, active ride banner, recent rides |
| Symptoms | Quick-select chips + free text → `POST /rides/emergency` |
| Live Tracking | `flutter_map` (OpenStreetMap) — driver pin via WebSocket |
| Ride Detail | Status badge, timeline, "Track Live" |
| Ride History | Paginated list |
| Profile / Settings | Edit profile, Help & FAQ, Contact Us, sign out |

#### Driver portal (teal theme, accessible via drawer)
| Screen | Description |
|--------|-------------|
| Dashboard | Online/offline toggle (disabled until verified), pending ride cards with 30 s countdown, verification banner shown until admin approves |
| Active Ride | Status progression, flutter_map, cancel flow |
| Profile / Settings | Driver info + edit, sign out |

#### Role switching
Open the drawer → **Switch to Patient/Driver** or **Become a Driver/Patient** (add-role flow). An active-ride warning is shown before switching away from the driver portal.

#### GPS streaming
On accept, `GpsStreamNotifier` connects `/ws/driver/{id}`, streams `{"lat","lng"}` from `geolocator` every 10 m. REST fallback `PATCH /drivers/location` throttled to 1/5 s.

### Multi-role auth API

| Endpoint | Description |
|---|---|
| `POST /api/v1/auth/register` | `roles: ["patient","driver","both"]` — creates all profiles in one call |
| `POST /api/v1/auth/login` | Returns `roles[]`, `active_role`, `role` (legacy compat) |
| `POST /api/v1/auth/add-role` | Add driver or patient role to existing account |
| `POST /api/v1/auth/switch-role` | Switch active portal (updates `user.role`) |
| `GET  /api/v1/auth/me` | Returns all profiles + `driver_verified` flag |
| `GET  /api/v1/rides/pending` | Driver: unassigned rides sorted by distance (requires verified) |
| `POST /api/v1/rides/{id}/accept` | Atomic assignment — 409 if race-lost (requires verified) |

### FCM setup

Place `google-services.json` in `apps/patient_app/android/app/`. Register package `com.smartride.patient_app` in Firebase console.

### Run the app

```bash
# Copy env template (points to backend — use your machine's LAN IP for physical device)
cp apps/patient_app/.env.example apps/patient_app/.env
# Edit API_BASE_URL=http://<your-ip>:8000

cd apps/patient_app
flutter pub get
flutter run
```

### Build release APK

```bash
cd apps/patient_app
flutter build apk --debug    # debug (no signing needed)
flutter build apk --release  # release (requires keystore secrets in GitHub)
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

## Env variables

See `.env.example` for all required variables.

Real secrets needed for full functionality:
- `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM_NUMBER` — SMS
- `FIREBASE_PROJECT_ID` — push notifications (Flutter apps use `google-services.json`, not an env var)

Maps use OpenStreetMap via `flutter_map` — no API key required.

All external dependencies have graceful fallbacks so the core dispatch pipeline works without any API keys.
