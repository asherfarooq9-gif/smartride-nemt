"""A scheduled ride cannot be started while the driver is far from the patient."""

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.models.models import RideStatus, RideType
from app.services.emergency_dispatch import DRIVER_FRESH_SECONDS
from app.services.ride_service import _ensure_driver_at_pickup

NOW = datetime(2026, 11, 2, 9, 0, tzinfo=timezone.utc)
PICKUP = (33.7000, 73.0400)
# 0.001 degrees of latitude is about 111 m.
NEAR = (33.7010, 73.0400)
FAR = (33.7100, 73.0400)


def _ride(ride_type=RideType.scheduled):
    return SimpleNamespace(
        ride_type=ride_type, pickup_lat=PICKUP[0], pickup_lng=PICKUP[1]
    )


def _driver(position, seen=NOW):
    lat, lng = position if position else (None, None)
    return SimpleNamespace(current_lat=lat, current_lng=lng, last_seen_at=seen)


def _check(ride, driver, status=RideStatus.patient_picked_up):
    _ensure_driver_at_pickup(ride, status, driver, NOW)


def test_a_driver_at_the_pickup_may_start_a_scheduled_ride():
    _check(_ride(), _driver(NEAR))


def test_a_driver_far_from_the_pickup_is_refused_with_the_distance():
    with pytest.raises(HTTPException) as refused:
        _check(_ride(), _driver(FAR))

    assert refused.value.status_code == 409
    assert "from the pickup" in refused.value.detail


def test_an_emergency_is_never_blocked():
    _check(_ride(RideType.emergency), _driver(FAR))


def test_only_the_pickup_step_is_checked():
    _check(_ride(), _driver(FAR), status=RideStatus.arrived_at_hospital)


def test_an_unknown_location_does_not_block_the_driver():
    _check(_ride(), _driver(None))


def test_a_stale_location_does_not_block_the_driver():
    stale = NOW - timedelta(seconds=DRIVER_FRESH_SECONDS + 1)

    _check(_ride(), _driver(FAR, seen=stale))
    _check(_ride(), _driver(FAR, seen=None))
