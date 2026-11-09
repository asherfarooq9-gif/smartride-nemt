"""In-ride chat: who may talk, what is stored, and when it is deleted.

Access rule: only the ride's own patient and the driver who accepted it, and only
while the ride is live with that driver on it. Admins are not participants.
Messages are deleted the moment the ride ends (see purge_ride_messages).
"""

import logging
import uuid
from dataclasses import dataclass

from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.models import (
    Driver,
    Patient,
    Ride,
    RideMessage,
    RideStatus,
    User,
)
from app.services.notifications import notify_user
from app.services.ws_manager import location_manager

log = logging.getLogger("smartride.chat")

# Chat is open only while a driver has the ride. Pending means no driver yet (or
# the driver gave it back); completed and cancelled mean the trip is over.
CHAT_OPEN_STATUSES = (
    RideStatus.driver_assigned,
    RideStatus.driver_en_route,
    RideStatus.patient_picked_up,
    RideStatus.arrived_at_hospital,
)
PAGE_LIMIT = 200


@dataclass(frozen=True)
class ChatAccess:
    ride: Ride
    role: str  # "patient" or "driver": which side the caller is on
    other_user_id: uuid.UUID | None


async def open_chat(db: AsyncSession, user: User, ride_id: uuid.UUID) -> ChatAccess:
    """Check the caller may use this ride's chat right now.

    404 unknown ride, 403 not a participant, 409 the chat is not open (no driver
    yet, or the ride is over).
    """
    ride = (
        await db.execute(select(Ride).where(Ride.id == ride_id))
    ).scalar_one_or_none()
    if ride is None:
        raise HTTPException(404, "Ride not found")

    patient = (
        await db.execute(select(Patient).where(Patient.user_id == user.id))
    ).scalar_one_or_none()
    driver = (
        await db.execute(select(Driver).where(Driver.user_id == user.id))
    ).scalar_one_or_none()

    if patient is not None and ride.patient_id == patient.id:
        role = "patient"
    elif (
        driver is not None
        and ride.driver_id is not None
        and ride.driver_id == driver.id
    ):
        role = "driver"
    else:
        raise HTTPException(403, "You are not part of this ride")

    if ride.status not in CHAT_OPEN_STATUSES or ride.driver_id is None:
        raise HTTPException(
            409, "Chat opens once a driver accepts and closes when the ride ends"
        )

    if role == "patient":
        other = (
            await db.execute(select(Driver.user_id).where(Driver.id == ride.driver_id))
        ).scalar_one_or_none()
    else:
        other = (
            await db.execute(
                select(Patient.user_id).where(Patient.id == ride.patient_id)
            )
        ).scalar_one_or_none()
    return ChatAccess(ride=ride, role=role, other_user_id=other)


async def list_messages(
    db: AsyncSession, ride_id: uuid.UUID, after_id: int | None = None
) -> list[RideMessage]:
    query = select(RideMessage).where(RideMessage.ride_id == ride_id)
    if after_id is not None:
        query = query.where(RideMessage.id > after_id)
    query = query.order_by(RideMessage.id).limit(PAGE_LIMIT)
    return list((await db.execute(query)).scalars())


async def add_message(
    db: AsyncSession, access: ChatAccess, user: User, body: str
) -> RideMessage:
    message = RideMessage(
        ride_id=access.ride.id,
        sender_user_id=user.id,
        sender_role=access.role,
        body=body,
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)
    return message


async def publish_message(message: RideMessage) -> None:
    """Show the message on the other person's open chat screen at once.

    Best effort: if Redis is down the message is already saved, and the other
    side gets it from the next fetch and from the push.
    """
    payload = {
        "id": message.id,
        "ride_id": str(message.ride_id),
        "sender": message.sender_role,
        "body": message.body,
        "created_at": message.created_at.isoformat(),
    }
    try:
        await location_manager.publish_chat(str(message.ride_id), payload)
    except Exception:  # noqa: BLE001 - a live-delivery failure must never fail the send
        log.warning(
            "chat publish failed ride_id=%s; message saved",
            message.ride_id,
            exc_info=True,
        )


async def tell_other_side(db: AsyncSession, access: ChatAccess) -> None:
    """Push "new message" to the other person. Never raises, and never carries the
    text: a lock screen must not show what a patient said about their health."""
    if access.other_user_id is None:
        return
    who = "driver" if access.role == "driver" else "patient"
    try:
        await notify_user(
            db,
            user_id=access.other_user_id,
            title="New message",
            body=f"Your {who} sent you a message.",
            data={"ride_id": str(access.ride.id), "type": "chat"},
        )
    except Exception as exc:  # noqa: BLE001 - a lost push must not fail the send
        log.warning(
            "chat push not sent ride_id=%s (%s)", access.ride.id, type(exc).__name__
        )


async def purge_ride_messages(db: AsyncSession, ride_id: uuid.UUID) -> None:
    """Delete a ride's chat. Part of the caller's transaction: it commits (or not)
    together with the status change that ended the chat."""
    await db.execute(delete(RideMessage).where(RideMessage.ride_id == ride_id))


async def purge_ended_ride_messages(db: AsyncSession) -> int:
    """Safety net: delete chats on rides that are not live with a driver.

    The status update already deletes at the moment a ride ends; this catches any
    other way a ride can end (a database fix, a future code path).
    """
    live = select(Ride.id).where(
        Ride.status.in_(CHAT_OPEN_STATUSES), Ride.driver_id.is_not(None)
    )
    result = await db.execute(
        delete(RideMessage).where(RideMessage.ride_id.not_in(live))
    )
    await db.commit()
    return result.rowcount or 0
