"""Seeding creates a working admin without shipping a well-known password."""

import re

from sqlalchemy import text

import seed as seed_script
from tests.conftest import TEST_DATABASE_URL

ADMIN_PHONE = "+92300000001"


async def _remove_seed_data(db) -> None:
    await db.execute(text("DELETE FROM users WHERE phone = :p"), {"p": ADMIN_PHONE})
    await db.execute(text("DELETE FROM hospitals WHERE address = 'G-8/3, Islamabad'"))
    await db.commit()


async def _login(client, password: str):
    return await client.post(
        "/api/v1/auth/login", json={"phone": ADMIN_PHONE, "password": password}
    )


async def test_seeded_admin_uses_the_configured_password(client, db, monkeypatch):
    monkeypatch.setattr(seed_script, "DB_URL", TEST_DATABASE_URL)
    monkeypatch.setenv("ADMIN_PASSWORD", "chosen-by-the-operator")
    await _remove_seed_data(db)
    try:
        await seed_script.seed()
        await seed_script.seed()  # idempotent: a second run must not duplicate or fail

        ok = await _login(client, "chosen-by-the-operator")
        assert ok.status_code == 200, ok.text
        assert ok.json()["role"] == "admin"
        assert (await _login(client, "admin123")).status_code == 401

        roles = await db.execute(
            text(
                "SELECT count(*) FROM user_roles ur JOIN users u ON u.id = ur.user_id "
                "WHERE u.phone = :p"
            ),
            {"p": ADMIN_PHONE},
        )
        assert roles.scalar() == 1
    finally:
        await db.rollback()
        await _remove_seed_data(db)


async def test_without_a_configured_password_a_random_one_is_generated(
    client, db, monkeypatch, capsys
):
    monkeypatch.setattr(seed_script, "DB_URL", TEST_DATABASE_URL)
    monkeypatch.delenv("ADMIN_PASSWORD", raising=False)
    await _remove_seed_data(db)
    try:
        await seed_script.seed()

        printed = re.search(r"password=(\S+)", capsys.readouterr().out).group(1)
        assert printed != "admin123"
        assert len(printed) >= 12
        assert (await _login(client, printed)).status_code == 200
    finally:
        await db.rollback()
        await _remove_seed_data(db)
