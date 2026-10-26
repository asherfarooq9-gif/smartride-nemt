# Observability — SmartRide NEMT

What's wired so you can run a pilot without flying blind.

## Stack

| Concern | Tool | Where |
|---------|------|-------|
| Metrics | Prometheus | `http://localhost:9090` |
| Dashboards | Grafana | `http://localhost:3001` (admin/admin by default) |
| HTTP + domain metrics | prometheus-fastapi-instrumentator + custom counters | backend `/metrics` |
| Error tracking | Sentry (env-gated) | enabled when `SENTRY_DSN` is set |
| Request tracing | StructuredLoggingMiddleware | every response carries `X-Trace-Id` |
| Mobile crashes | Firebase Crashlytics | `apps/patient_app` (`FlutterError.onError`) |

Bring the monitoring services up:

```bash
docker compose up -d prometheus grafana
```

## Backend metrics

HTTP metrics come from the instrumentator. Domain metrics (`app/core/metrics.py`):

- `smartride_rides_created_total{ride_type}`
- `smartride_rides_accepted_total`
- `smartride_ride_accept_conflicts_total` — dispatch-race losers (409)
- `smartride_dispatch_failures_total{reason}` — `no_hospital` / `no_driver`
- `smartride_emergency_dispatch_seconds` — pipeline duration histogram (60s SLO)

## Dashboard

Grafana auto-provisions **"SmartRide — Service Overview"** (`monitoring/grafana/dashboards/smartride.json`):
request rate, 5xx error %, latency p95, rides created by type, accept conflicts,
emergency dispatch p95 vs the 60s SLO, and dispatch failures by reason.

## Alerts

Prometheus rules (`monitoring/prometheus/alerts.yml`):

| Alert | Condition | Severity |
|-------|-----------|----------|
| `BackendDown` | scrape target down >1m | critical |
| `HighServerErrorRate` | >5% 5xx over 5m | critical |
| `DispatchFailuresSpiking` | >5 dispatch failures in 10m | warning |
| `SlowEmergencyDispatch` | dispatch p95 >60s for 5m | warning |
| `DatabaseUnreachable` | `smartride_dependency_up{dependency="database"}` is 0 for 1m | critical |
| `RedisUnreachable` | `smartride_dependency_up{dependency="redis"}` is 0 for 1m | critical |
| `DispatchLoopStalled` | no clean dispatch loop pass for 2m | critical |
| `RideWaitingForDriver` | longest-waiting pending emergency ride over 2m | critical |
| `PatientOrHospitalNotNotified` | a driver, hospital pre-alert or hospital cancel notice failed to send | critical |
| `WalletLedgerMismatch` | a driver's balance differs from the sum of their ledger rows | critical |

The dependency, pending-ride, loop and ledger gauges are refreshed by the dispatch
loop every pass (`app/services/health_metrics.py`), so a loop that has died shows up
as `DispatchLoopStalled` rather than as silence. A test fails if a rule uses a metric
the backend does not export.

### Delivering alerts

Prometheus sends firing alerts to the `alertmanager` service
(`monitoring/alertmanager/alertmanager.yml`). **Its receiver is a placeholder that
discards every alert**, so until you replace it nobody is paged. Choose who is on call
and the channel (Slack, email, PagerDuty, Opsgenie, a webhook), put the secret in a
mounted file (`api_url_file`, `password_file`), and send a test alert:

```bash
curl -XPOST localhost:9093/api/v2/alerts -H 'Content-Type: application/json'   -d '[{"labels":{"alertname":"TestAlert","severity":"critical"}}]'
```

## Error tracking

`SENTRY_DSN` unset → no-op (local/CI stay offline). When set, unhandled exceptions
are captured. PHI safety: `send_default_pii=False` and a `before_send` hook scrubs
`Authorization`/`Cookie` headers. Every error response includes a `trace_id` that
matches the server log line and the Sentry event, so support can correlate a user
report to an exact request.

## Config

| Env var | Default | Notes |
|---------|---------|-------|
| `SENTRY_DSN` | "" | empty = error tracking off |
| `SENTRY_TRACES_SAMPLE_RATE` | 0.1 | perf trace sampling |
| `ENVIRONMENT` | development | Sentry environment tag |
| `GRAFANA_USER` / `GRAFANA_PASSWORD` | admin / admin | **change for any shared deploy** |

## Still open

- A real Alertmanager receiver (owner decision: who is on call, on which channel).
- Log aggregation (Loki/ELK) — logs are structured JSON but only go to stdout.
- Distributed tracing spans (OpenTelemetry) if the triage microservice hop needs timing.
