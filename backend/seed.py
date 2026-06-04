"""
Seed script — creates admin user + demo hospitals.
Run inside the backend container:
  docker exec -it smartride_backend python seed.py
Or locally:
  cd backend && python seed.py
"""

import asyncio
import json
import os
import uuid

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.core.config import settings
from app.core.security import hash_password

DB_URL = os.environ.get("DATABASE_URL", settings.DATABASE_URL)

HOSPITALS = [
    dict(
        name="Pakistan Institute of Medical Sciences (PIMS)",
        address="G-8/3, Islamabad",
        city="Islamabad",
        lat=33.6938,
        lng=73.0651,
        specialties=["cardiology", "neurology", "emergency", "orthopedics"],
        ed_capacity=200,
        ed_current_load=120,
        is_active=True,
    ),
    dict(
        name="Shifa International Hospital",
        address="H-8/4, Islamabad",
        city="Islamabad",
        lat=33.6691,
        lng=73.0569,
        specialties=["cardiology", "oncology", "orthopedics", "neurology"],
        ed_capacity=150,
        ed_current_load=60,
        is_active=True,
    ),
    dict(
        name="Poly Clinic Hospital",
        address="G-6, Islamabad",
        city="Islamabad",
        lat=33.7197,
        lng=73.0900,
        specialties=["emergency", "general", "pediatrics"],
        ed_capacity=100,
        ed_current_load=45,
        is_active=True,
    ),
    dict(
        name="Holy Family Hospital",
        address="Satellite Town, Rawalpindi",
        city="Rawalpindi",
        lat=33.6007,
        lng=73.0679,
        specialties=["emergency", "obstetrics", "pediatrics", "general"],
        ed_capacity=180,
        ed_current_load=100,
        is_active=True,
    ),
    dict(
        name="Benazir Bhutto Hospital",
        address="College Road, Rawalpindi",
        city="Rawalpindi",
        lat=33.5902,
        lng=73.0478,
        specialties=["emergency", "cardiology", "neurology"],
        ed_capacity=250,
        ed_current_load=190,
        is_active=True,
    ),
]


async def seed() -> None:
    engine = create_async_engine(DB_URL, echo=False)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with factory() as db:
        # Admin user — use raw SQL to avoid Python enum → Postgres type mismatch
        row = await db.execute(
            text("SELECT id FROM users WHERE phone = '+92300000001'")
        )
        if row.first() is None:
            await db.execute(
                text(
                    "INSERT INTO users (id, phone, password_hash, role, is_active) "
                    "VALUES (:id, :phone, :pw, 'admin'::user_role, true)"
                ),
                {
                    "id": str(uuid.uuid4()),
                    "phone": "+92300000001",
                    "pw": hash_password("admin123"),
                },
            )
            print("  Created admin user  phone=+92300000001  password=admin123")
        else:
            print("  Admin user already exists — skipped")

        # Hospitals — raw SQL to avoid same enum issue with specialties JSON
        for h in HOSPITALS:
            row = await db.execute(
                text("SELECT id FROM hospitals WHERE name = :name"), {"name": h["name"]}
            )
            if row.first() is None:
                await db.execute(
                    text(
                        "INSERT INTO hospitals (id, name, address, city, lat, lng, specialties, "
                        "ed_capacity, ed_current_load, is_active) "
                        "VALUES (:id, :name, :address, :city, :lat, :lng, :specialties::json, "
                        ":ed_capacity, :ed_current_load, :is_active)"
                    ),
                    {
                        "id": str(uuid.uuid4()),
                        "name": h["name"],
                        "address": h["address"],
                        "city": h["city"],
                        "lat": h["lat"],
                        "lng": h["lng"],
                        "specialties": json.dumps(h["specialties"]),
                        "ed_capacity": h["ed_capacity"],
                        "ed_current_load": h["ed_current_load"],
                        "is_active": h["is_active"],
                    },
                )
                print(f"  Created hospital: {h['name']}")
            else:
                print(f"  Hospital already exists — skipped: {h['name']}")

        await db.commit()

    await engine.dispose()
    print("\nSeed complete.")


if __name__ == "__main__":
    asyncio.run(seed())
