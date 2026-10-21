"""A device token belongs to one account: pushes about a ride must reach only its people."""

import uuid

from sqlalchemy import select

from app.models.models import User
from tests.test_review_fixes import _auth, _register


def _phone() -> str:
    return f"+92300{str(uuid.uuid4().int)[:7]}"


async def _stored_token(db, user_id) -> str | None:
    db.expire_all()
    return (
        await db.execute(select(User.fcm_token).where(User.id == user_id))
    ).scalar_one()


async def _user_id(client, token) -> str:
    return (await client.get("/api/v1/auth/me", headers=_auth(token))).json()["user_id"]


async def test_registering_a_token_stores_it(client, db):
    token = await _register(client, _phone(), "patient")
    r = await client.post(
        "/api/v1/auth/fcm-token", json={"fcm_token": "device-1"}, headers=_auth(token)
    )
    assert r.status_code == 204
    assert await _stored_token(db, await _user_id(client, token)) == "device-1"


async def test_a_device_handed_to_another_account_stops_receiving_the_first_ones_pushes(
    client, db
):
    first = await _register(client, _phone(), "patient")
    second = await _register(client, _phone(), "patient")
    first_id, second_id = await _user_id(client, first), await _user_id(client, second)
    shared = f"device-{uuid.uuid4().hex}"

    await client.post(
        "/api/v1/auth/fcm-token", json={"fcm_token": shared}, headers=_auth(first)
    )
    await client.post(
        "/api/v1/auth/fcm-token", json={"fcm_token": shared}, headers=_auth(second)
    )

    assert await _stored_token(db, second_id) == shared
    assert await _stored_token(db, first_id) is None
