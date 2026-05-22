"""
Seed script — creates admin user + demo hospitals.
Run inside the backend container:
  docker exec -it smartride_backend python seed.py
Or locally:
  cd backend && python seed.py
"""
import asyncio
import os
import sys

from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.models.models import User, Hospital, UserRole

DB_URL = os.environ.get("DATABASE_URL", settings.DATABASE_URL)

HOSPITALS = [
    dict(name="Pakistan Institute of Medical Sciences (PIMS)", address="G-8/3, Islamabad",
         city="Islamabad", lat=33.6938, lng=73.0651,
         specialties=["cardiology", "neurology", "emergency", "orthopedics"],
         ed_capacity=200, ed_current_load=120, is_active=True),
    dict(name="Shifa International Hospital", address="H-8/4, Islamabad",
         city="Islamabad", lat=33.6691, lng=73.0569,
         specialties=["cardiology", "oncology", "orthopedics", "neurology"],
         ed_capacity=150, ed_current_load=60, is_active=True),
    dict(name="Poly Clinic Hospital", address="G-6, Islamabad",
         city="Islamabad", lat=33.7197, lng=73.0900,
         specialties=["emergency", "general", "pediatrics"],
         ed_capacity=100, ed_current_load=45, is_active=True),
    dict(name="Holy Family Hospital", address="Satellite Town, Rawalpindi",
         city="Rawalpindi", lat=33.6007, lng=73.0679,
         specialties=["emergency", "obstetrics", "pediatrics", "general"],
         ed_capacity=180, ed_current_load=100, is_active=True),
    dict(name="Benazir Bhutto Hospital", address="College Road, Rawalpindi",
         city="Rawalpindi", lat=33.5902, lng=73.0478,
         specialties=["emergency", "cardiology", "neurology"],
         ed_capacity=250, ed_current_load=190, is_active=True),
]


async def seed() -> None:
    engine = create_async_engine(DB_URL, echo=False)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with factory() as db:
        # Admin user
        existing = await db.execute(select(User).where(User.phone == "+92300000001"))
        if existing.scalar_one_or_none() is None:
            admin = User(
                phone="+92300000001",
                password_hash=hash_password("admin123"),
                role=UserRole.admin,
                is_active=True,
            )
            db.add(admin)
            print("  Created admin user  phone=+92300000001  password=admin123")
        else:
            print("  Admin user already exists — skipped")

        # Hospitals
        for h in HOSPITALS:
            existing = await db.execute(select(Hospital).where(Hospital.name == h["name"]))
            if existing.scalar_one_or_none() is None:
                db.add(Hospital(**h))
                print(f"  Created hospital: {h['name']}")
            else:
                print(f"  Hospital already exists — skipped: {h['name']}")

        await db.commit()

    await engine.dispose()
    print("\nSeed complete.")


if __name__ == "__main__":
    asyncio.run(seed())
