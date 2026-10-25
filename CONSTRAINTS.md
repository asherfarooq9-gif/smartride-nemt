# Quality Constraints

Written bar for this project. Every item below is already enforced by CI unless marked "proposed". An agent or human may raise a threshold but must not lower one, add a suppression, skip a test or delete an assertion to get green. If a constraint is wrong, change it here in its own commit with the reason.

## Enforced today

| Area | Constraint | Enforced by |
|---|---|---|
| Backend lint | `ruff check` clean (rules E4, E7, E9, F, W) and `ruff format --check` | `ci.yml` Backend Lint |
| Backend tests | All pass; coverage at least 60% of `app` (measured ~66%) | `ci.yml` `--cov-fail-under=60` |
| Migrations | `alembic upgrade head` succeeds on a clean DB | `ci.yml` migration sanity step |
| Flutter | `flutter analyze` clean, all tests pass, debug APK builds | `ci.yml` Flutter job |
| Triage service | All tests pass | `ci.yml` Triage job |
| Dashboard | `npm run lint`, `npm run typecheck`, `npm run build` pass | `ci.yml` Dashboard job |
| Dashboard e2e | Playwright passes on desktop, tablet and mobile viewports | `ci.yml` E2E job |
| Compose | `docker-compose.yml` and `docker-compose.prod.yml` validate | `ci.yml` compose job |
| Secrets | No secrets in history or diff | `security.yml` gitleaks |
| Python SAST | Bandit, medium severity and above, clean | `security.yml` |
| Dependencies | `pip-audit`, `npm audit`, Trivy image scan reviewed | `security.yml` |

## Rules for changes

- No new `# noqa`, `# type: ignore`, `eslint-disable`, `@ts-ignore` or `// ignore:` without a one-line reason beside it.
- No `skip`, `xfail` or deleted tests without a reason and an issue or follow-up noted in the PR.
- Bug fix: add a failing test first (Prove-It), then the fix.
- Dispatch, auth, money and PHI code: new behaviour needs tests that cover the failure path, not only the happy path.
- Coverage must not fall in a PR that touches `backend/app`.

## Proposed (not yet enforced, agree before adding)

| Area | Proposal |
|---|---|
| Backend coverage | Raise the floor from 60% toward 75% on `app/services` (dispatch, money) |
| Dashboard accessibility | axe checks in Playwright, zero serious or critical violations |
| Dashboard performance | LCP under 2.5s, INP under 200ms, CLS under 0.1 on key pages (`/webperf`) |
| Flutter coverage | Set a floor once the current `lcov` baseline is measured |
| Type checking | `mypy` is installed in the lint job but not gating; decide scope before enforcing |
