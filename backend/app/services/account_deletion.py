"""Account deletion that keeps the records the database must keep.

Rides and the wallet ledger cannot be deleted (their foreign keys are RESTRICT
and the ledger is append-only), so "delete my account" anonymizes instead: the
person's data is cleared or replaced with a placeholder, the login stops working
and every session ends. Rows, ride history and money records stay, so
statistics, driver payouts and audits still add up.
"""

import secrets
import uuid

from sqlalchemy import Numeric, cast, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password_async
from app.models.models import (
    Driver,
    DriverStatus,
    Patient,
    Ride,
    TriageEvent,
    User,
)
from app.services.retention import PURGED_MARKER
from app.services.ride_service import TERMINAL_STATUSES

DELETED_PATIENT_NAME = "Deleted user"
DELETED_DRIVER_NAME = "Deleted driver"
DELETED_VEHICLE_TYPE = "deleted"
# Decimal places kept on a pickup point: 2 is about 1 km, enough for area
# statistics but not a home address.
PICKUP_PRECISION = 2


class ActiveRideError(Exception):
    """The account is part of a ride that is still in progress."""


async def _has_active_ride(db: AsyncSession, *, patient_id, driver_id) -> bool:
    live = Ride.status.not_in(TERMINAL_STATUSES)
    checks = []
    if patient_id is not None:
        checks.append(select(Ride.id).where(Ride.patient_id == patient_id, live))
    if driver_id is not None:
        checks.append(select(Ride.id).where(Ride.driver_id == driver_id, live))
    for check in checks:
        if (await db.execute(check.limit(1))).first() is not None:
            return True
    return False


async def _anonymize_patient(db: AsyncSession, patient: Patient) -> None:
    patient.full_name = DELETED_PATIENT_NAME
    patient.date_of_birth = None
    patient.mobility_needs = None
    patient.emergency_contact_name = None
    patient.emergency_contact_phone = None

    await db.execute(
        update(TriageEvent)
        .where(
            TriageEvent.ride_id.in_(
                select(Ride.id).where(Ride.patient_id == patient.id)
            )
        )
        .values(symptom_text=PURGED_MARKER)
    )
    await db.execute(
        update(Ride)
        .where(Ride.patient_id == patient.id)
        .values(
            pickup_address=None,
            symptom_text=None,
            rating_comment=None,
            cancel_reason=None,
            pickup_lat=cast(
                cast(Ride.pickup_lat, Numeric), Numeric(9, PICKUP_PRECISION)
            ),
            pickup_lng=cast(
                cast(Ride.pickup_lng, Numeric), Numeric(9, PICKUP_PRECISION)
            ),
        )
    )


async def _release_claims(db: AsyncSession, driver: Driver) -> None:
    """A deleted driver keeps no booked rides hidden from everyone else."""
    await db.execute(
        update(Ride)
        .where(Ride.claimed_driver_id == driver.id, Ride.driver_id.is_(None))
        .values(claimed_driver_id=None, claimed_at=None)
    )


def _anonymize_driver(driver: Driver, suffix: str) -> None:
    driver.payment_methods = []
    driver.full_name = DELETED_DRIVER_NAME
    # Both are unique and required, so they get a unique placeholder.
    driver.license_no = f"deleted-{suffix}"
    driver.vehicle_plate = f"deleted-{suffix}"
    driver.vehicle_type = DELETED_VEHICLE_TYPE
    driver.is_verified = False
    driver.status = DriverStatus.offline
    driver.current_lat = None
    driver.current_lng = None
    driver.last_seen_at = None
    # wallet_balance_pkr and the ledger are money records: never touched.


async def anonymize_account(db: AsyncSession, user: User) -> None:
    """Anonymize [user] and every profile they hold. Does not commit.

    Raises ActiveRideError, changing nothing, if they are in a live ride.
    """
    patient = (
        await db.execute(select(Patient).where(Patient.user_id == user.id))
    ).scalar_one_or_none()
    driver = (
        await db.execute(select(Driver).where(Driver.user_id == user.id))
    ).scalar_one_or_none()

    if await _has_active_ride(
        db,
        patient_id=patient.id if patient else None,
        driver_id=driver.id if driver else None,
    ):
        raise ActiveRideError

    suffix = uuid.uuid4().hex[:12]
    if patient is not None:
        await _anonymize_patient(db, patient)
    if driver is not None:
        await _release_claims(db, driver)
        _anonymize_driver(driver, suffix)

    # Phone is unique and required: a placeholder that cannot be dialled and
    # frees the real number to register again. The password becomes a random
    # one nobody knows.
    user.phone = f"deleted-{suffix}"
    user.password_hash = await hash_password_async(secrets.token_urlsafe(32))
    user.fcm_token = None
    user.is_active = False
    user.token_version = user.token_version + 1
