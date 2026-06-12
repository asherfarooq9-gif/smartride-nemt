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

> To deliver alerts (Slack/email/PagerDuty) add an Alertmanager service and point
> Prometheus at it. Rules already evaluate; only the notifier is missing.

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

- Alertmanager + a real notification channel.
- Log aggregation (Loki/ELK) — logs are structured JSON but only go to stdout.
- Distributed tracing spans (OpenTelemetry) if the triage microservice hop needs timing.
