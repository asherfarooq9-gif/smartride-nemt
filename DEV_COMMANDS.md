# Dev Commands

Quick reference for running each part of Smart Ride NEMT locally. PowerShell, Windows.

## Docker (backend, db, redis, celery — all containerized services)

Repo root: `D:\Smart_Ride_NEMT`

```powershell
cd D:\Smart_Ride_NEMT
docker compose up --build          # foreground, build + start all services
docker compose up -d --build       # detached (background)
docker compose logs -f             # tail logs (all services)
docker compose logs -f backend     # tail logs (single service)
docker compose ps                  # list running containers
docker compose down                # stop + remove containers
docker compose down -v             # stop + remove containers AND volumes (wipes db data)
docker compose restart backend     # restart one service
```

## Patient App (Flutter)

Dir: `D:\Smart_Ride_NEMT\apps\patient_app`

```powershell
cd D:\Smart_Ride_NEMT\apps\patient_app
flutter pub get                    # install deps
flutter run                        # run on connected device/emulator
flutter run -d chrome              # run in Chrome
flutter run -d windows             # run as Windows desktop app
flutter test                       # run tests
flutter build apk                  # build Android APK
flutter build windows              # build Windows exe
flutter analyze                    # static analysis / lint
```

## Backend (FastAPI, without Docker)

Dir: `D:\Smart_Ride_NEMT\backend`

```powershell
cd D:\Smart_Ride_NEMT\backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
pytest                             # run tests
pytest --cov=app                   # run tests with coverage
alembic upgrade head                # apply db migrations
alembic revision --autogenerate -m "message"   # new migration
```

## AI Triage Service

Dir: `D:\Smart_Ride_NEMT\ai-services\triage`

```powershell
cd D:\Smart_Ride_NEMT\ai-services\triage
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --reload --port 8001
pytest                             # run tests
```

## Admin Dashboard (Next.js)

Dir: `D:\Smart_Ride_NEMT\admin-dashboard`

```powershell
cd D:\Smart_Ride_NEMT\admin-dashboard
npm install
npm run dev                        # dev server
npm run build                      # production build
npm run start                      # run production build
npm run lint
npm run test                       # vitest
```

## Run everything together

```powershell
# Terminal 1 — infra + backend
cd D:\Smart_Ride_NEMT
docker compose up -d --build

# Terminal 2 — admin dashboard
cd D:\Smart_Ride_NEMT\admin-dashboard
npm run dev

# Terminal 3 — patient app
cd D:\Smart_Ride_NEMT\apps\patient_app
flutter run -d chrome
```
