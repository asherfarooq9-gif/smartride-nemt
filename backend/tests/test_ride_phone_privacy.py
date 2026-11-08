"""Patient and driver never get each other's phone number.

They reach each other through in-app chat and internet calls, so a trip does not
hand out a real number that can be used (or misused) long after it ends. Dispatch
(admin) still sees both numbers, and each person still sees their own.
"""

from tests.test_ride_lifecycle import _assigned_ride, _auth, _phone


async def _detail(client, token, ride_id) -> dict:
    r = await client.get(f"/api/v1/rides/{ride_id}/detail", headers=_auth(token))
    assert r.status_code == 200, r.text
    return r.json()


async def test_the_driver_does_not_get_the_patients_number(
    client, verified_driver_token
):
    patient_phone = _phone()
    _, ride_id = await _assigned_ride(client, patient_phone, verified_driver_token)

    detail = await _detail(client, verified_driver_token, ride_id)

    assert detail["patient"]["full_name"]
    assert detail["patient"]["phone"] is None
    assert patient_phone not in str(detail)


async def test_the_patient_does_not_get_the_drivers_number(
    client, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    driver_phone = (
        await client.get("/api/v1/drivers/me", headers=_auth(verified_driver_token))
    ).json()["phone"]

    detail = await _detail(client, patient_token, ride_id)

    assert detail["driver"]["full_name"]
    assert detail["driver"]["phone"] is None
    assert driver_phone not in str(detail)


async def test_dispatch_still_sees_both_numbers(
    client, admin_token, verified_driver_token
):
    patient_phone = _phone()
    _, ride_id = await _assigned_ride(client, patient_phone, verified_driver_token)
    driver_phone = (
        await client.get("/api/v1/drivers/me", headers=_auth(verified_driver_token))
    ).json()["phone"]

    detail = await _detail(client, admin_token, ride_id)

    assert detail["patient"]["phone"] == patient_phone
    assert detail["driver"]["phone"] == driver_phone


async def test_each_person_still_sees_their_own_number(client, verified_driver_token):
    patient_phone = _phone()
    patient_token, ride_id = await _assigned_ride(
        client, patient_phone, verified_driver_token
    )
    driver_phone = (
        await client.get("/api/v1/drivers/me", headers=_auth(verified_driver_token))
    ).json()["phone"]

    as_patient = await _detail(client, patient_token, ride_id)
    as_driver = await _detail(client, verified_driver_token, ride_id)

    assert as_patient["patient"]["phone"] == patient_phone
    assert as_driver["driver"]["phone"] == driver_phone


async def test_no_number_is_handed_over_after_the_ride_ends(
    client, verified_driver_token
):
    patient_phone = _phone()
    patient_token, ride_id = await _assigned_ride(
        client, patient_phone, verified_driver_token
    )
    driver_phone = (
        await client.get("/api/v1/drivers/me", headers=_auth(verified_driver_token))
    ).json()["phone"]
    r = await client.patch(
        f"/api/v1/rides/{ride_id}/status",
        json={"status": "cancelled"},
        headers=_auth(patient_token),
    )
    assert r.status_code == 200, r.text

    for token in (patient_token, verified_driver_token):
        text = str(await _detail(client, token, ride_id))
        assert text.count(patient_phone) <= 1  # only the patient's own copy
        if token == patient_token:
            assert driver_phone not in text
        else:
            assert patient_phone not in text
