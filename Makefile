.PHONY: up down build logs seed test shell-backend shell-db ps clean test-triage test-flutter test-e2e lint test-all

# ── Docker ────────────────────────────────────────────────────────────────────

up:
	docker compose up -d

build:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f

ps:
	docker compose ps

clean:
	docker compose down -v --remove-orphans

# ── Database ──────────────────────────────────────────────────────────────────

seed:
	docker exec smartride_backend python seed.py

migrate:
	docker exec smartride_backend alembic upgrade head

shell-backend:
	docker exec -it smartride_backend bash

shell-db:
	docker exec -it smartride_postgres psql -U smartride smartride

# ── Tests ─────────────────────────────────────────────────────────────────────

test:
	cd backend && pytest -v --tb=short

test-backend:
	docker exec smartride_backend pytest -v --tb=short

# ── Quality gate (what CI runs) ───────────────────────────────────────────────
# Backend tests need Postgres + Redis:  docker compose up -d postgres redis
# `test-e2e` needs them too, plus E2E_PYTHON pointing at an interpreter that has
# backend/requirements.txt installed. It starts the API and dashboard itself.

test-triage:
	cd ai-services/triage && pytest -q

test-flutter:
	cd packages/smartride_core && flutter test
	cp -n apps/patient_app/.env.example apps/patient_app/.env
	cd apps/patient_app && flutter analyze && flutter test

test-e2e:
	cd admin-dashboard && npx playwright test

lint:
	cd backend && ruff check . && ruff format --check .
	cd admin-dashboard && npm run lint && npm run typecheck

test-all: test test-triage test-flutter test-e2e
