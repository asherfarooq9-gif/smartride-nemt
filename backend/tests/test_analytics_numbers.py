"""The dashboard numbers must be the real numbers."""

from tests.test_dispatch_endpoints import _create_emergency, _register
from tests.test_review_fixes import _auth
from tests.test_ride_lifecycle import _phone, _set_ride_status


async def _summary(client, admin_token) -> dict:
    r = await client.get("/api/v1/analytics/summary", headers=_auth(admin_token))
    assert r.status_code == 200, r.text
    return r.json()


async def test_summary_counts_follow_a_ride_through_its_life(
    client, admin_token, verified_driver_token
):
    before = await _summary(client, admin_token)

    patient = await _register(client, _phone(), "patient")
    ride_id = await _create_emergency(client, patient)
    created = await _summary(client, admin_token)
    assert created["total_rides"] == before["total_rides"] + 1
    assert created["emergency_rides_24h"] == before["emergency_rides_24h"] + 1
    assert created["active_rides"] == before["active_rides"]

    await client.post(
        f"/api/v1/rides/{ride_id}/accept", headers=_auth(verified_driver_token)
    )
    for status in ("driver_en_route", "patient_picked_up", "arrived_at_hospital"):
        await _set_ride_status(client, verified_driver_token, ride_id, status)
        # Every state between acceptance and completion is an active ride,
        # including the patient already being at the hospital.
        assert (await _summary(client, admin_token))["active_rides"] == before[
            "active_rides"
        ] + 1, status

    await _set_ride_status(client, verified_driver_token, ride_id, "completed")
    done = await _summary(client, admin_token)
    assert done["active_rides"] == before["active_rides"]
    assert done["total_rides"] == before["total_rides"] + 1
