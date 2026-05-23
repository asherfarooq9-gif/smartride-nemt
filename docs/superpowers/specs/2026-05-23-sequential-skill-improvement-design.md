# SmartRide NEMT — Sequential Skill Improvement Design

**Date:** 2026-05-23
**Author:** Asher
**Status:** Approved

## Overview

Apply eight sequential improvement skills to the SmartRide NEMT codebase to achieve holistic quality improvements across code health, security, testing, observability, API design, performance, backend architecture, and the admin dashboard. Timeline: ~1 month.

The project is already functional: FastAPI backend with full routers (auth, rides, drivers, hospitals, patients, analytics, WebSocket), complete Flutter patient/driver apps, Next.js admin dashboard, AI triage/demand microservices, PostgreSQL + Redis, and 1,073 lines of existing tests. The README milestone table is outdated — most features are implemented.

---

## Stage 1 — Code Review (`review` skill)

**Scope:** All Python backend code (routers, services, models, schemas, core), the Next.js admin dashboard (components, pages, API routes), and key Flutter app files.

**Outputs:**
- Enumerated list of bugs, anti-patterns, and dead code
- Style and naming inconsistencies
- Any missing error handling at service boundaries
- Quick-wins (< 30 min fixes) flagged separately

**Success criteria:** No regressions introduced; every identified issue either fixed or explicitly deferred with rationale.

---

## Stage 2 — Security Review (`security-review` skill)

**Scope:** Beyond the existing 9-fix security pass, audit:
- JWT expiry and refresh token flow
- CORS policy correctness
- Rate limiting on auth and emergency endpoints
- Input validation completeness (Pydantic schemas vs. raw params)
- Secrets in environment vs. code
- WebSocket connection authentication
- Admin dashboard authentication and authorization

**Outputs:**
- Prioritized list of remaining vulnerabilities (Critical / High / Medium)
- Code fixes for all Critical and High items
- Notes on Medium items with mitigation recommendations

**Success criteria:** No Critical or High vulnerabilities remain unaddressed.

---

## Stage 3 — Testing (`tdd-guide` skill)

**Scope:** Current baseline is 1,073 lines across 7 test files (`test_auth`, `test_crud`, `test_dispatch`, `test_hospital_matching`, `test_rides`, `test_websocket`, `test_analytics`).

**Gaps to address:**
- Unhappy-path coverage for all critical flows: failed dispatch, no drivers available, token expiry, invalid coordinates
- WebSocket authentication edge cases
- Hospital matching edge cases (no hospitals in range, all hospitals at capacity)
- Admin API endpoint tests (currently absent)
- Ensure all tests pass cleanly with no flakiness

**Outputs:**
- New test cases filling identified gaps
- Fixed flaky or environment-sensitive tests
- Coverage report (pytest-cov) with line-coverage ≥ 80% on backend services

**Success criteria:** `make test` passes with zero failures; coverage ≥ 80% on `app/services/` and `app/routers/`.

---

## Stage 4 — Observability (`observability-designer` skill)

**Scope:** FastAPI backend and Docker deployment.

**Additions:**
- Structured JSON logging with correlation IDs on every request (via middleware)
- `/health` endpoint (liveness) and `/ready` endpoint (readiness — checks DB + Redis connectivity)
- Basic Prometheus metrics endpoint (`/metrics`) or statsd integration: request count, latency p50/p99, dispatch pipeline duration, active WebSocket connections
- Log levels configurable via `LOG_LEVEL` env var

**Integration:** Fits into existing `docker-compose.yml` without new required services. Prometheus scrape is optional/additive.

**Success criteria:** Every incoming request produces a structured log line with trace ID; `/health` and `/ready` return correctly under normal and degraded conditions.

---

## Stage 5 — API Design Review (`api-design-reviewer` skill)

**Scope:** Full REST API contract as implemented in `backend/app/routers/`.

**Areas to review:**
- Consistent error response shape (currently some endpoints return bare strings, others return dicts)
- Pagination on all list endpoints (`/rides`, `/drivers`, `/hospitals`)
- Correct HTTP status codes (201 vs 200 on creation, 422 vs 400, etc.)
- Naming consistency (snake_case fields, plural resource names)
- API versioning strategy — evaluate whether `/v1/` prefix is needed for FYP scope

**Outputs:**
- Concrete backward-compatible changes to router code and Pydantic schemas
- Updated OpenAPI spec (auto-generated via FastAPI)

**Success criteria:** All list endpoints paginated; all error responses share a single `{detail: string, code: string}` shape; HTTP status codes match RFC semantics.

---

## Stage 6 — Performance (`performance-profiler` skill)

**Scope:** Backend database queries, Redis usage, and async patterns.

**Focus areas:**
- N+1 query detection in ride/driver/hospital fetches (use `joinedload` / `selectinload` where needed)
- Missing database indexes (foreign keys, status columns used in WHERE clauses, geo-search columns)
- Redis caching opportunities: hospital list (rarely changes), triage model results, analytics aggregates
- Audit async usage — ensure no `requests` / blocking I/O called inside async routes
- Connection pool sizing review

**Outputs:**
- Added `Index()` declarations in SQLAlchemy models
- `selectinload`/`joinedload` added to N+1 query sites
- Redis cache layer for identified hot paths
- Fixed any sync-in-async violations

**Success criteria:** No N+1 queries on the three most-called endpoints; hot paths have measurable cache hit; no blocking I/O in async context.

---

## Stage 7 — Backend Architecture (`senior-backend` skill)

**Scope:** FastAPI application architecture, building on Stage 1 and Stage 5 findings.

**Areas:**
- Extract repeated DB-fetch patterns into reusable service functions (DRY routers)
- Strengthen service layer separation (routers call services; services call models — no SQLAlchemy in routers)
- Pydantic v2 schema hygiene: ensure `model_config`, validators, and field aliases are consistent
- Alembic migration hygiene: verify all model changes have corresponding migrations; add missing indexes as migrations
- Celery task error handling and retry policies
- Review `tasks.py` for robustness

**Outputs:**
- Refactored routers delegating to service layer
- Updated Alembic migrations for any missing schema changes
- Celery tasks with retry/backoff policies

**Success criteria:** No SQLAlchemy session usage directly in router functions; all schema changes covered by migrations.

---

## Stage 8 — Admin Dashboard (`senior-frontend` skill)

**Scope:** Next.js admin dashboard (`admin-dashboard/`).

**Areas:**
- Consistent loading and error states across all data fetches (no bare `undefined` renders)
- Fix TypeScript `any` types — strengthen to proper interfaces
- Add empty states for tables/lists when data is absent
- Responsive layout review for smaller screens (≥ 768px breakpoint)
- Component structure: extract repeated table/card patterns into shared components
- Review Tailwind config for unused classes / purge correctness

**Outputs:**
- Loading skeleton or spinner on all async data
- Error boundary or inline error messages
- TypeScript interfaces for all API response shapes
- At least one shared `<DataTable>` component replacing repeated table markup

**Success criteria:** No TypeScript errors (`tsc --noEmit` passes); no `any` types in component props; all pages handle loading/error/empty states.

---

## Execution Order and Dependencies

```
Stage 1 (Code Review) ─────────────────────────────────────────────────┐
Stage 2 (Security) — independent of Stage 1, can start after         │
Stage 3 (Testing) — depends on Stage 1 findings                       │
Stage 4 (Observability) — independent                                  │
Stage 5 (API Design) — depends on Stage 1 findings                    ├─ All feed Stage 7
Stage 6 (Performance) — depends on Stage 1 findings                   │
Stage 7 (Backend Arch) — depends on Stages 1, 5, 6                   │
Stage 8 (Admin Dashboard) — independent of Stages 1-7               ──┘
```

Stages 2, 4, 8 can run in parallel with earlier stages if desired. Stages 3, 5, 6 should wait for Stage 1 findings. Stage 7 should be last among the backend stages.

---

## Out of Scope

- New feature development (AI demand forecasting, FHIR notifications, payment integration)
- Flutter app changes (apps are considered complete)
- Infrastructure changes (no new required Docker services)
- Database data migrations (schema-only changes)
