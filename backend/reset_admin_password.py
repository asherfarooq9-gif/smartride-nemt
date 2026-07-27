"""
Reset (or create) the admin login credentials.
Run inside the backend container so it hits the same database the API uses:
  docker exec -it smartride_backend python reset_admin_password.py
Or locally, if DATABASE_URL in your environment points at the right database:
  cd backend && python reset_admin_password.py
"""

import asyncio
import os
import uuid

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.config import settings
from app.core.security import hash_password

DB_URL = os.environ.get("DATABASE_URL", settings.DATABASE_URL)

ADMIN_PHONE = "+92300000001"
ADMIN_PASSWORD = "admin123"


async def reset_admin_password() -> None:
    engine = create_async_engine(DB_URL, echo=False)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with factory() as db:
        row = await db.execute(
            text("SELECT id FROM users WHERE phone = :phone"), {"phone": ADMIN_PHONE}
        )
        existing = row.first()

        if existing is None:
            await db.execute(
                text(
                    "INSERT INTO users (id, phone, password_hash, role, is_active) "
                    "VALUES (:id, :phone, :pw, 'admin'::user_role, true)"
                ),
                {
                    "id": str(uuid.uuid4()),
                    "phone": ADMIN_PHONE,
                    "pw": hash_password(ADMIN_PASSWORD),
                },
            )
            print(f"  Created admin user  phone={ADMIN_PHONE}  password={ADMIN_PASSWORD}")
        else:
            await db.execute(
                text(
                    "UPDATE users SET password_hash = :pw, role = 'admin'::user_role, "
                    "is_active = true WHERE phone = :phone"
                ),
                {"pw": hash_password(ADMIN_PASSWORD), "phone": ADMIN_PHONE},
            )
            print(f"  Reset admin password  phone={ADMIN_PHONE}  password={ADMIN_PASSWORD}")

        await db.commit()

    await engine.dispose()
    print("\nDone.")


if __name__ == "__main__":
    asyncio.run(reset_admin_password())
