# PHI / Patient-Data Compliance Audit — SmartRide NEMT

**Date:** 2026-06-12
**Scope:** Backend handling of patient health information (PHI) and personal data —
storage, transit, logging, API exposure, access control, and external disclosure.
**Context:** Medical transport (Islamabad/Rawalpindi pilot). Data subjects are
patients with health complaints. Pakistan has no single HIPAA-equivalent, but the
PECA framework + general duty of care for medical data apply; this audit uses
HIPAA "minimum necessary" and standard data-protection practice as the bar.

---

## PHI / personal-data inventory

| Data | Where | Sensitivity |
|------|-------|-------------|
| Raw symptom free-text | `triage_events.symptom_text` | **High** — health complaint |
| Predicted specialty / severity | `triage_events` | High — health inference |
| Mobility needs | `patients.mobility_needs` | High — disability/health |
| Full name, DOB | `patients` | Medium — identifying |
| Phone | `users.phone`, emergency/coordinator | Medium — identifying |
| Pickup location | `rides.pickup_lat/lng/address` | Medium — location + implies care event |
| Emergency contact | `patients.emergency_contact_*` | Medium — third-party PII |
| Family SMS body | `family_notifications.message_body` | Medium — name + destination |

---

## Findings

### Fixed this pass

| # | Severity | Finding | Fix |
|---|----------|---------|-----|
| 1 | **HIGH** | PHI in application logs: `notifications.py` used `print()` to log the **full SMS body** (patient name, hospital, driver) and **full recipient phone** to stdout → container logs. | Replaced with `log.*`; body never logged; phone masked to last 3 digits; exceptions log type only (text can echo body/phone). |
| 2 | **HIGH** | PHI over-disclosure: `GET /rides/{id}/detail` returned identical payload to all roles, so the **assigned driver received the raw `symptom_text`** (free-text health complaint). Driver needs specialty + severity only. | Scoped `symptom_text` to patient (own data) + admin. Driver gets specialty/severity. Also fixed a dual-role authz gap (owner-patient who also holds driver role was mis-routed). |
| 3 | **MEDIUM** | No HSTS / Permissions-Policy header — PHI could ride a downgraded cleartext connection. | Added `Strict-Transport-Security` (1y, includeSubDomains) and `Permissions-Policy`. |

### Open — recommended next (not changed this pass)

| # | Severity | Finding | Recommendation |
|---|----------|---------|----------------|
| 4 | **MEDIUM** | No data-retention / erasure policy. `symptom_text`, family SMS bodies, locations stored indefinitely. No patient self-delete / right-to-erasure endpoint. | Define retention (e.g. purge raw `symptom_text` N days after ride completion; keep specialty/severity for analytics). Add an account/data deletion path. |
| 5 | **MEDIUM** | No PHI-access audit trail. Who viewed a patient's ride detail / symptom_text is not recorded. | Log (separately from request logs) every read of `symptom_text` / patient detail with actor, subject, timestamp. |
| 6 | **MEDIUM** | PHI columns stored plaintext in Postgres. Relies on disk encryption at the hosting layer. | Confirm managed Postgres has encryption-at-rest enabled; document it. Consider app-level encryption for `symptom_text` if the DB host is shared/untrusted. |
| 7 | **LOW** | `.env` ships `DEBUG=True`. Prod must set `DEBUG=False`. | The config validator already blocks insecure `SECRET_KEY` and wildcard CORS when `DEBUG=False` — ensure prod deploy sets it. |
| 8 | **LOW** | No regression test asserting the driver-scoped `symptom_text` hiding (#2). | Add an integration test: assigned driver fetching `/detail` must not receive `symptom_text`; owning patient must. |

---

## Controls already in place (verified — good)

- Passwords hashed with **bcrypt**; never returned in any response schema.
- JWT carries `jti`; logout/refresh **revoke** tokens via Redis blocklist.
- Ride-detail enforces **ownership** (patient owns ride / driver assigned / admin).
- Production config validator rejects the default `SECRET_KEY` and wildcard CORS when `DEBUG=False`.
- Hospital pre-alert **FHIR bundle references the patient by UUID**, not name — minimal PHI to the hospital.
- Structured request logging records **method/path/status/duration only** — no bodies, no query strings.
- Security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` (now + HSTS/Permissions-Policy).
- Rate limiting on auth + global (200/min) — verified under load (0 crashes).

---

## Verification

- `ruff check` / `ruff format --check`: pass
- Backend tests after fixes: **77 passed**, coverage ~65%
- Manual: confirmed `symptom_text` only added to triage payload for `authorized_as in (patient, admin)`.
