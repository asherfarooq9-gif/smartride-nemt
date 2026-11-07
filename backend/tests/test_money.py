"""Fares, commission and the wallet ledger."""

import uuid
from decimal import Decimal

from sqlalchemy import func, select, update

from app.core.config import settings
from app.models.models import Driver, Hospital, Ride, WalletEntry
from app.services.fare import commission_for, fare_for
from app.services.ride_service import charge_commission
from tests.test_ride_lifecycle import _assigned_ride, _auth, _phone, _set_ride_status


async def _complete(client, driver_token, ride_id) -> None:
    for status in (
        "driver_en_route",
        "patient_picked_up",
        "arrived_at_hospital",
        "completed",
    ):
        r = await _set_ride_status(client, driver_token, ride_id, status)
        assert r.status_code == 200, r.text


async def _driver_row(db, token_client, token) -> Driver:
    me = await token_client.get("/api/v1/drivers/me", headers=_auth(token))
    db.expire_all()
    return (
        await db.execute(select(Driver).where(Driver.id == me.json()["id"]))
    ).scalar_one()


async def _ledger_total(db, driver_id) -> Decimal:
    return (
        await db.execute(
            select(func.coalesce(func.sum(WalletEntry.amount), 0)).where(
                WalletEntry.driver_id == driver_id
            )
        )
    ).scalar_one()


def test_fare_is_base_plus_per_km_rounded_to_paisa():
    base = Decimal(str(settings.FARE_BASE_PKR))
    per_km = Decimal(str(settings.FARE_PER_KM_PKR))
    assert fare_for(0) == base
    assert fare_for(10) == base + per_km * 10
    assert fare_for(1.2345) == (base + per_km * Decimal("1.2345")).quantize(
        Decimal("0.01")
    )


def test_commission_is_the_configured_share_of_the_fare():
    assert commission_for(Decimal("1000.00")) == Decimal("100.00")
    assert commission_for(Decimal("333.33")) == Decimal("33.33")


async def test_completing_a_ride_records_fare_and_commission(
    client, db, verified_driver_token
):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    hospital = Hospital(
        name="Fare Test Hospital",
        address="A",
        city="Islamabad",
        lat=33.7215 + 0.09,  # ~10 km north of the test pickup
        lng=73.0433,
        specialties=["general_emergency"],
        ed_capacity=10,
    )
    db.add(hospital)
    await db.flush()
    await db.execute(
        update(Ride).where(Ride.id == ride_id).values(hospital_id=hospital.id)
    )
    await db.commit()
    before = (await _driver_row(db, client, verified_driver_token)).wallet_balance_pkr

    await _complete(client, verified_driver_token, ride_id)

    db.expire_all()
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()
    fare = ride.final_fare_pkr
    assert fare > Decimal(str(settings.FARE_BASE_PKR))
    entries = (
        (await db.execute(select(WalletEntry).where(WalletEntry.ride_id == ride_id)))
        .scalars()
        .all()
    )
    assert [e.kind for e in entries] == ["commission"]
    amount = entries[0].amount
    assert amount == -commission_for(fare)
    driver = await _driver_row(db, client, verified_driver_token)
    assert driver.wallet_balance_pkr == before + amount


async def test_commission_is_charged_once_per_ride(client, db, verified_driver_token):
    _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
    await _complete(client, verified_driver_token, ride_id)
    driver = await _driver_row(db, client, verified_driver_token)
    balance, driver_id = driver.wallet_balance_pkr, driver.id
    ride = (await db.execute(select(Ride).where(Ride.id == ride_id))).scalar_one()

    assert await charge_commission(db, ride, driver_id) is False

    db.expire_all()
    assert (
        await _driver_row(db, client, verified_driver_token)
    ).wallet_balance_pkr == balance


async def test_wallet_balance_always_equals_the_ledger(
    client, db, admin_token, verified_driver_token
):
    driver = await _driver_row(db, client, verified_driver_token)
    top_up = await client.post(
        f"/api/v1/drivers/{driver.id}/wallet/topup",
        json={"amount_pkr": 700, "payment_method": "jazzcash"},
        headers={**_auth(admin_token), "Idempotency-Key": uuid.uuid4().hex},
    )
    assert top_up.status_code == 200, top_up.text
    for _ in range(2):
        _, ride_id = await _assigned_ride(client, _phone(), verified_driver_token)
        await _complete(client, verified_driver_token, ride_id)

    driver = await _driver_row(db, client, verified_driver_token)
    assert driver.wallet_balance_pkr == await _ledger_total(db, driver.id)
    wallet = await client.get(
        "/api/v1/drivers/wallet", headers=_auth(verified_driver_token)
    )
    kinds = {t["type"] for t in wallet.json()["transactions"]}
    assert {"topup", "commission"} <= kinds
    assert wallet.json()["balance_pkr"] == float(driver.wallet_balance_pkr)
