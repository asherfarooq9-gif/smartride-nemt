"""Wallet top-up is money: reject non-finite, negative and absurd amounts."""

import uuid

import pytest
from httpx import AsyncClient

from tests.test_review_fixes import _auth, _driver_extra, _register


async def _driver_id(client: AsyncClient, phone: str) -> str:
    token = await _register(client, phone, "driver", **_driver_extra())
    return (await client.get("/api/v1/drivers/me", headers=_auth(token))).json()["id"]


async def _topup_raw(client: AsyncClient, admin_token: str, driver_id: str, body: str):
    return await client.post(
        f"/api/v1/drivers/{driver_id}/wallet/topup",
        content=body,
        headers={**_auth(admin_token), "Content-Type": "application/json"},
    )


@pytest.mark.asyncio
@pytest.mark.parametrize("amount", ["NaN", "Infinity", "-Infinity", "-5", "0", "1e12"])
async def test_topup_rejects_invalid_amounts(client, admin_token, amount):
    driver_id = await _driver_id(client, f"+9230076{uuid.uuid4().int % 10**4:04d}")
    r = await _topup_raw(
        client,
        admin_token,
        driver_id,
        f'{{"amount_pkr": {amount}, "payment_method": "jazzcash"}}',
    )
    assert r.status_code == 422, r.text

    me = await client.get(
        f"/api/v1/drivers?search={driver_id}", headers=_auth(admin_token)
    )
    assert me.status_code == 200


@pytest.mark.asyncio
async def test_topup_unknown_driver_id_is_404_not_500(client, admin_token):
    r = await client.post(
        f"/api/v1/drivers/{uuid.uuid4()}/wallet/topup",
        json={"amount_pkr": 100, "payment_method": "jazzcash"},
        headers=_auth(admin_token),
    )
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_topup_malformed_driver_id_is_422_not_500(client, admin_token):
    r = await client.post(
        "/api/v1/drivers/not-a-uuid/wallet/topup",
        json={"amount_pkr": 100, "payment_method": "jazzcash"},
        headers=_auth(admin_token),
    )
    assert r.status_code == 422
