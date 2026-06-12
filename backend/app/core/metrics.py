"""Domain (business) Prometheus metrics.

The prometheus-fastapi-instrumentator already exposes HTTP-level metrics
(request count, latency, status). These add ride-lifecycle visibility — the
things an NEMT operator actually watches: are rides being created, dispatched,
and accepted, and how often does the dispatch race conflict.

All series are exposed on the same /metrics endpoint.
"""

from prometheus_client import Counter, Histogram

rides_created_total = Counter(
    "smartride_rides_created_total",
    "Rides created, labelled by type.",
    ["ride_type"],
)

rides_accepted_total = Counter(
    "smartride_rides_accepted_total",
    "Rides successfully accepted by a driver.",
)

ride_accept_conflicts_total = Counter(
    "smartride_ride_accept_conflicts_total",
    "Accept attempts that lost the race (HTTP 409).",
)

dispatch_failures_total = Counter(
    "smartride_dispatch_failures_total",
    "Emergency dispatch pipeline failures, labelled by reason.",
    ["reason"],
)

emergency_dispatch_seconds = Histogram(
    "smartride_emergency_dispatch_seconds",
    "Wall-clock time of the emergency dispatch pipeline.",
    buckets=(1, 2, 5, 10, 20, 30, 45, 60, 90, 120),
)
