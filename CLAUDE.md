# SmartRide NEMT

Emergency and non-emergency medical transport platform (Islamabad/Rawalpindi pilot). Handles patient health data (PHI) and payments, so treat auth, dispatch and money code as high-risk.

## Layout

| Path | Stack |
|---|---|
| `backend/` | FastAPI, PostgreSQL (PostGIS), Redis, Alembic |
| `ai-services/triage/` | Symptom-to-specialty classifier (FastAPI) |
| `admin-dashboard/` | Next.js, Playwright e2e |
| `apps/patient_app/`, `packages/smartride_core/` | Flutter |
| `docs/` | System design, API contract, runbooks, security and PHI audits |

## Commands

```bash
docker compose up -d postgres redis   # needed for backend tests
make test                             # backend pytest
make test-triage                      # triage service
make test-flutter                     # core package + patient app (analyze + test)
make test-e2e                         # dashboard Playwright
cd admin-dashboard && npm run lint && npm run typecheck && npm run build
cd backend && ruff check . && ruff format --check .
```

CI (`.github/workflows/ci.yml`, `security.yml`) runs all of the above. Match it locally before pushing.

## Skills workflow

Agent-skills are installed globally. Use them in this order for non-trivial work:

1. `/spec` (spec-driven-development) when requirements are unclear. Save to `SPEC.md`.
2. `/agent-plan` (planning-and-task-breakdown). Do not use `/plan`, that is the ECC command.
3. `/build` and `/test`: thin vertical slices, test first, one commit per task.
4. `/review` before merge. `/code-simplify` only on code you just touched.
5. `/ship` before any release. `/webperf` for dashboard changes.

Always-apply skills:
- `security-and-hardening` for auth, input handling, PHI, payments, dispatch.
- `debugging-and-error-recovery` for any failing test or build: find the root cause, never skip or weaken a test.
- `api-and-interface-design` when changing `docs/api-contract.md` or endpoints.
- `deprecation-and-migration` for Alembic migrations (expand/contract, no destructive drops in one step).
- `documentation-and-adrs` for architecture decisions. Record ADRs in `docs/adr/`.
- `observability-and-instrumentation` for new production paths. See `docs/OBSERVABILITY.md`.

Quality bar lives in `CONSTRAINTS.md` (constraint-driven-development). Never lower it to get green.

## Rules for this repo

- Never commit secrets. `.env.example` only; the secret scan (gitleaks) is a CI gate.
- Dispatch and money logic need race and resilience tests. Follow `backend/tests/test_dispatch_races.py` and `test_money.py`.
- The triage keyword list is vendored from `ai-services/triage/keywords.py` into `backend/app/services/triage_keywords.py`. Change the source, then copy; a test checks they match.
- Migrations must pass `backend/tests/test_migrations.py`.
