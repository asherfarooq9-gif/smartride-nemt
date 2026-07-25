# SmartRide NEMT — Deployment & Operations Runbook

Environment setup, build/run instructions, and troubleshooting for the SmartRide
platform (FastAPI backend, Flutter patient app, Next.js admin dashboard,
rule-based/ML triage service, Postgres, Redis, Celery, Prometheus/Grafana).

## 1. Prerequisites

- Docker + Docker Compose
- Python 3.11 (only for running backend tooling outside containers)
- Node 20+ (admin dashboard)
- Flutter 3.41+ (patient app)

## 2. Environment configuration

Copy the templates and fill in real values:

```bash
cp .env.example .env
cp admin-dashboard/.env.example admin-dashboard/.env.local
```

Required for production (`DEBUG=false`) — the backend refuses to start otherwise
(`app/core/config.py` validator):

- `SECRET_KEY` — 32+ char random string (never the placeholder)
- `ALLOWED_ORIGINS` — explicit origins, never `["*"]`

Optional integrations are no-ops when unset: Twilio (SMS), Google Maps, Firebase
(FCM), Sentry (error tracking), and `TRIAGE_SERVICE_URL` (falls back to keyword
rules when blank — see `render.yaml`).

## 3. Local run (Docker Compose)

```bash
docker compose up -d              # postgres, redis, backend, triage, celery, admin, prometheus, grafana
docker compose --profile pooling up -d   # additionally start PgBouncer
docker compose ps                 # all services should report healthy
```

All services now have healthchecks; `backend`/`admin`/`celery` use `start_period`
grace windows, so `ps` may show `starting` for the first 20–40s.

Service URLs:

| Service         | URL                     |
|-----------------|-------------------------|
| Backend API     | http://localhost:8000   |
| API docs (DEBUG)| http://localhost:8000/docs |
| Triage          | http://localhost:8001   |
| Admin dashboard | http://localhost:3000   |
| Prometheus      | http://localhost:9090   |
| Grafana         | http://localhost:3001   |

## 4. Database migrations

Migrations are Alembic-managed (`backend/alembic/versions/`, head `0006`).

```bash
docker exec smartride_backend alembic upgrade head    # apply
docker exec smartride_backend alembic current         # show current revision
docker exec smartride_backend alembic downgrade -1    # roll back one
```

Seed reference data (hospitals, demo users):

```bash
docker exec smartride_backend python seed.py
```

## 5. Running tests

### Backend (in container)

The test suite needs a **separate** database and the service hostnames (not
localhost) when run inside the container. Create the test DB once:

```bash
docker exec smartride_postgres psql -U smartride -d smartride -c "CREATE DATABASE smartride_test;"
```

Then:

```bash
docker exec \
  -e TEST_DATABASE_URL="postgresql+asyncpg://smartride:password@postgres:5432/smartride_test" \
  -e REDIS_URL="redis://redis:6379/1" \
  -e TRIAGE_SERVICE_URL="http://triage:8001" \
  smartride_backend pytest --cov=app --cov-report=term-missing
```

> Note: `pytest-asyncio` is in `requirements.txt` (installed in the container and
> CI) but may be absent from a bare host Python. Run the suite in the container,
> or `pip install -r backend/requirements.txt` first.

### Triage service

```bash
docker exec smartride_triage sh -c "cd /app && python -m pytest -q"
```

### Admin dashboard

```bash
cd admin-dashboard && npm install && npm test
```

### Flutter app

```bash
cd apps/patient_app && flutter pub get && flutter test
```

## 6. Triage model (optional ML upgrade)

The triage service ships a rule-based classifier (`model_version="rules-v1.0"`).
To train the DistilBERT model that replaces specialty inference:

```bash
cd ai-services/triage/data
pip install transformers datasets scikit-learn pandas torch
python train_distilbert.py        # saves ./distilbert-hospital-routing-final
```

Export to ONNX and mount into the `triage_model` volume (`MODEL_PATH=/app/model`),
then wire `infer_specialty()` to the model — always passing output through
`specialties.normalize_specialty()`. Keep the keyword rules as fallback. See
`ai-services/triage/DATASET.md`.

## 7. API documentation

FastAPI auto-generates OpenAPI. `/docs` (Swagger) and `/redoc` are exposed only
when `DEBUG=true`. Export the spec:

```bash
curl http://localhost:8000/openapi.json > openapi.json
```

The hand-written contract lives in `docs/api-contract.md`.

## 8. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `port ... 3000 already in use` on `up` | Another process holds the port. Find it (`Get-NetTCPConnection -LocalPort 3000`) and stop it, or remap the host port in `docker-compose.yml`. |
| Login returns `Internal server error`, logs show `column users.X does not exist` | Migrations not applied. Run `alembic upgrade head`. |
| Tests fail with `Connect call failed ('127.0.0.1', 5432)` | Missing `TEST_DATABASE_URL` pointing at the `postgres` service host — see §5. |
| Backend refuses to start in prod | `SECRET_KEY` is placeholder or `ALLOWED_ORIGINS` contains `*` — set real values. |
| Triage returns `general_emergency` for everything | `TRIAGE_SERVICE_URL` unreachable; backend fell back to keyword rules. Check the `triage` container health. |

## 9. Production deploy

`render.yaml` defines the Render.com deployment (Postgres + backend Docker web
service, health check `/health`). Mobile builds are defined in `codemagic.yaml`
(Android APK, iOS IPA). See `docs/OPERATIONS.md` for backup/restore and staging.
