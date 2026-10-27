"""Wallet ledger: DB-level guards, idempotent Decimal top-ups, negative balances."""

import uuid
from decimal import Decimal

import pytest
from sqlalchemy import delete, func, select, update
from sqlalchemy.exc import DBAPIError, IntegrityError

from app.models.models import Driver, WalletEntry
from app.services.driver_service import apply_balance_delta
from tests.test_review_fixes import _auth, _driver_extra, _register


async def _driver(client, db) -> uuid.UUID:
    phone = f"+9230078{uuid.uuid4().int % 10**4:04d}"
    token = await _register(client, phone, "driver", **_driver_extra())
    me = await client.get("/api/v1/drivers/me", headers=_auth(token))
    return uuid.UUID(me.json()["id"])


async def _topup(client, admin_token, driver_id, key=None, **body):
    body = {"amount_pkr": "100.00", "payment_method": "jazzcash", **body}
    headers = {**_auth(admin_token), "Idempotency-Key": key or uuid.uuid4().hex}
    return await client.post(
        f"/api/v1/drivers/{driver_id}/wallet/topup", json=body, headers=headers
    )


async def _entries(db, driver_id) -> list[WalletEntry]:
    db.expire_all()
    return list(
        (
            await db.execute(
                select(WalletEntry).where(WalletEntry.driver_id == driver_id)
            )
        )
        .scalars()
        .all()
    )


# ── database guards ───────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("kind", "amount"),
    [
        ("refund", Decimal("5")),  # unknown kind
        ("topup", Decimal("-5")),
        ("topup", Decimal("0")),
        ("commission", Decimal("5")),
        ("commission", Decimal("0")),
    ],
)
async def test_ledger_rejects_bad_kind_or_sign(client, db, kind, amount):
    driver_id = await _driver(client, db)
    db.add(WalletEntry(driver_id=driver_id, kind=kind, amount=amount))
    with pytest.raises(IntegrityError):
        await db.commit()
    await db.rollback()


async def test_adjustment_may_be_either_sign(client, db):
    driver_id = await _driver(client, db)
    db.add(WalletEntry(driver_id=driver_id, kind="adjustment", amount=Decimal("-3")))
    db.add(WalletEntry(driver_id=driver_id, kind="adjustment", amount=Decimal("3")))
    await db.commit()
    assert len(await _entries(db, driver_id)) == 2


async def test_ledger_rows_cannot_be_updated_or_deleted(client, db):
    driver_id = await _driver(client, db)
    db.add(WalletEntry(driver_id=driver_id, kind="adjustment", amount=Decimal("1")))
    await db.commit()

    with pytest.raises(DBAPIError, match="append-only"):
        await db.execute(
            update(WalletEntry)
            .where(WalletEntry.driver_id == driver_id)
            .values(amount=Decimal("999"))
        )
    await db.rollback()
    with pytest.raises(DBAPIError, match="append-only"):
        await db.execute(delete(WalletEntry).where(WalletEntry.driver_id == driver_id))
    await db.rollback()


async def test_driver_with_ledger_history_cannot_be_deleted(client, db):
    driver_id = await _driver(client, db)
    db.add(WalletEntry(driver_id=driver_id, kind="adjustment", amount=Decimal("1")))
    await db.commit()

    with pytest.raises(IntegrityError):
        await db.execute(delete(Driver).where(Driver.id == driver_id))
    await db.rollback()


async def test_idempotency_key_is_unique_in_the_database(client, db):
    driver_id = await _driver(client, db)
    for _ in range(2):
        db.add(
            WalletEntry(
                driver_id=driver_id,
                kind="topup",
                amount=Decimal("1"),
                idempotency_key="dup-key",
            )
        )
    with pytest.raises(IntegrityError):
        await db.commit()
    await db.rollback()


# ── top-up behaviour ──────────────────────────────────────────────────────────


async def test_topup_without_idempotency_key_is_rejected(client, db, admin_token):
    """A keyless retry would credit twice (NULL keys never conflict), so refuse it."""
    driver_id = await _driver(client, db)

    r = await client.post(
        f"/api/v1/drivers/{driver_id}/wallet/topup",
        json={"amount_pkr": "100.00", "payment_method": "jazzcash"},
        headers=_auth(admin_token),
    )

    assert r.status_code == 422, r.text
    assert await _entries(db, driver_id) == []


async def test_topup_replay_with_same_key_credits_once(client, db, admin_token):
    driver_id = await _driver(client, db)
    key = f"k-{uuid.uuid4()}"

    first = await _topup(client, admin_token, driver_id, key)
    replay = await _topup(client, admin_token, driver_id, key)

    assert first.status_code == replay.status_code == 200
    assert (
        first.json()["wallet_balance_pkr"] == replay.json()["wallet_balance_pkr"] == 100
    )
    entries = await _entries(db, driver_id)
    assert [(e.kind, e.amount) for e in entries] == [("topup", Decimal("100.00"))]
    assert entries[0].idempotency_key == key


async def test_topup_key_reused_for_another_amount_is_a_conflict(
    client, db, admin_token
):
    driver_id = await _driver(client, db)
    key = f"k-{uuid.uuid4()}"
    assert (await _topup(client, admin_token, driver_id, key)).status_code == 200

    r = await _topup(client, admin_token, driver_id, key, amount_pkr="250.00")

    assert r.status_code == 409
    assert len(await _entries(db, driver_id)) == 1


async def test_topup_records_who_and_how(client, db, admin_token):
    driver_id = await _driver(client, db)

    r = await _topup(client, admin_token, driver_id, payment_method="easypaisa")

    assert r.status_code == 200
    entry = (await _entries(db, driver_id))[0]
    assert entry.payment_method == "easypaisa"
    assert entry.admin_user_id is not None


async def test_topup_is_exact_to_the_paisa(client, db, admin_token):
    driver_id = await _driver(client, db)
    for amount in ("0.10", "0.20", "10.10"):
        assert (
            await _topup(client, admin_token, driver_id, amount_pkr=amount)
        ).status_code == 200

    db.expire_all()
    balance = (
        await db.execute(
            select(Driver.wallet_balance_pkr).where(Driver.id == driver_id)
        )
    ).scalar_one()
    assert balance == Decimal("10.40")
    ledger = (
        await db.execute(
            select(func.sum(WalletEntry.amount)).where(
                WalletEntry.driver_id == driver_id
            )
        )
    ).scalar_one()
    assert ledger == balance


async def test_topup_rejects_sub_paisa_amounts(client, db, admin_token):
    driver_id = await _driver(client, db)
    r = await _topup(client, admin_token, driver_id, amount_pkr="1.001")
    assert r.status_code == 422


async def test_topup_unknown_plan_is_422_not_a_silent_fallback(client, db, admin_token):
    driver_id = await _driver(client, db)
    r = await _topup(client, admin_token, driver_id, plan_id="platinum")
    assert r.status_code == 422
    assert await _entries(db, driver_id) == []


async def test_topup_known_plan_credits_the_plan_price(client, db, admin_token):
    driver_id = await _driver(client, db)
    r = await _topup(client, admin_token, driver_id, plan_id="starter", amount_pkr="0")
    assert r.status_code == 200, r.text
    assert (await _entries(db, driver_id))[0].amount == Decimal("250")


# ── balance rules ─────────────────────────────────────────────────────────────


async def test_balance_may_go_negative(client, db):
    driver_id = await _driver(client, db)
    await apply_balance_delta(db, driver_id, Decimal("-40.50"))
    await db.commit()
    db.expire_all()
    balance = (
        await db.execute(
            select(Driver.wallet_balance_pkr).where(Driver.id == driver_id)
        )
    ).scalar_one()
    assert balance == Decimal("-40.50")


async def test_balance_update_on_a_missing_driver_is_an_error(db):
    with pytest.raises(RuntimeError, match="expected exactly 1"):
        await apply_balance_delta(db, uuid.uuid4(), Decimal("1"))
    await db.rollback()
