"""The money and state-machine edges of a ride that the happy-path tests do not reach."""

from decimal import Decimal

from sqlalchemy import func, select, update

from app.models.models import Driver, Ride, RideStatus, WalletEntry
from tests.test_dispatch_endpoints import _register
from tests.test_money import _complete, _driver_row, _ledger_total
from tests.test_ride_lifecycle import _assigned_ride, _auth, _phone, _set_ride_status


async def _commission_rows(db, ride_id) -> int:
    return (
        await db.execute(
            select(func.count())
            .select_from(WalletEntry)
            .where(WalletEntry.ride_id == ride_id, WalletEntry.kind == "commission")
        )
    ).scalar_one()


async def test_a_cancelled_ride_costs_the_driver_nothing(
    client, db, verified_driver_token
):
    patient_token, ride_id = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    driver = await _driver_row(db, client, verified_driver_token)
    before = driver.wallet_balance_pkr

    r = await _set_ride_status(client, patient_token, ride_id, "cancelled")

    assert r.status_code == 200, r.text
    assert await _commission_rows(db, ride_id) == 0
    assert (
        await _driver_row(db, client, verified_driver_token)
    ).wallet_balance_pkr == before


async def test_completing_a_ride_twice_charges_one_commission(
    client, db, verified_driver_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    await _complete(client, verified_driver_token, ride_id)
    after_first = (
        await _driver_row(db, client, verified_driver_token)
    ).wallet_balance_pkr

    again = await _set_ride_status(client, verified_driver_token, ride_id, "completed")

    assert again.status_code == 400, again.text
    assert await _commission_rows(db, ride_id) == 1
    assert (
        await _driver_row(db, client, verified_driver_token)
    ).wallet_balance_pkr == after_first


async def test_a_driver_with_an_empty_wallet_still_completes_and_goes_negative(
    client, db, verified_driver_token
):
    """Commission is debited after the ride, so a negative balance is expected, and it
    must never stop a patient reaching the hospital."""
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    driver = await _driver_row(db, client, verified_driver_token)
    await db.execute(
        update(Driver).where(Driver.id == driver.id).values(wallet_balance_pkr=0)
    )
    await db.commit()

    await _complete(client, verified_driver_token, ride_id)

    after = await _driver_row(db, client, verified_driver_token)
    assert after.wallet_balance_pkr < 0
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
    assert ride.status == RideStatus.completed
    assert ride.final_fare_pkr is not None and ride.final_fare_pkr > Decimal(0)


async def test_a_driver_cannot_skip_steps_to_book_a_fare(
    client, db, verified_driver_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)

    for jump in ("patient_picked_up", "arrived_at_hospital", "completed"):
        r = await _set_ride_status(client, verified_driver_token, ride_id, jump)
        assert r.status_code == 400, f"{jump}: {r.text}"

    assert await _commission_rows(db, ride_id) == 0
    db.expire_all()
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
    assert ride.status == RideStatus.driver_assigned


async def test_another_driver_cannot_move_someone_elses_ride(
    client, db, verified_driver_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    other = await _register(
        client,
        _phone(),
        "driver",
        license_no=f"MP-{_phone()[-6:]}",
        vehicle_plate=f"MP-{_phone()[-5:]}",
        vehicle_type="sedan",
    )
    await db.execute(
        update(Driver)
        .where(Driver.id == (await _driver_row(db, client, other)).id)
        .values(is_verified=True)
    )
    await db.commit()

    r = await _set_ride_status(client, other, ride_id, "driver_en_route")

    assert r.status_code == 403, r.text
    assert (
        await client.get(
            f"/api/v1/rides/{ride_id}", headers=_auth(verified_driver_token)
        )
    ).json()["status"] == "driver_assigned"


async def test_the_ledger_total_still_matches_the_balance_after_these_paths(
    client, db, verified_driver_token
):
    _, done = await _assigned_ride(client, _phone(), verified_driver_token)
    await _complete(client, verified_driver_token, done)
    patient_token, cancelled = await _assigned_ride(
        client, _phone(), verified_driver_token
    )
    await _set_ride_status(client, patient_token, cancelled, "cancelled")

    driver = await _driver_row(db, client, verified_driver_token)

    assert driver.wallet_balance_pkr == await _ledger_total(db, driver.id)
