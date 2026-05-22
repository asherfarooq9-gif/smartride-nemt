.PHONY: up down build logs seed test shell-backend shell-db ps clean

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
