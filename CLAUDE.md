## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## Project overview

SmartRide NEMT — AI-powered emergency medical transport for Pakistan (Islamabad/Rawalpindi pilot).

### Multi-role auth (backend)
- `user_roles` join table holds all roles an account possesses
- `users.role` = active portal (patient | driver | admin)
- JWT carries `roles[]` (all), `active_role`, and `role` (legacy = active_role)
- Key endpoints: `POST /auth/register` (roles list), `/auth/add-role`, `/auth/switch-role`, `GET /auth/me`
- RBAC uses `held_roles` (set membership), not the active role
- Admin self-register is blocked via API — use the `admin_token` pytest fixture for tests

### Driver dispatch (backend)
- `GET /api/v1/rides/pending` — unassigned pending rides, sorted by distance to driver
- `POST /api/v1/rides/{id}/accept` — atomic assignment via `UPDATE … WHERE driver_id IS NULL`; returns 409 on race
- Both endpoints require `driver.is_verified == True` else 403

### Unified Flutter app (`apps/patient_app`)
- Single APK — patient portal (blue) + driver portal (teal), toggled via drawer
- `apps/driver_app` is **retired** — do not edit or build it; CI/release only builds `patient_app`
- GoRouter: `/` patient home, `/driver` driver dashboard, `/welcome` unauthenticated entry
- `rolesProvider` (all roles), `activeRoleProvider` (current portal) live in `core/providers.dart`
- `DriverResponse.isVerified` controls verification banner and online toggle in the driver dashboard
