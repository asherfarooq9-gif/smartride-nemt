"""In-ride chat endpoints: read and send messages for one ride."""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import require_role
from app.models.models import User
from app.routers.rides import limiter
from app.schemas.chat import MessageCreate, MessageListResponse, MessageResponse
from app.services import chat_service

router = APIRouter()

# The largest value a bigint column can hold; anything bigger is a bad request,
# not a database error.
MAX_MESSAGE_ID = 2**63 - 1

# Admins are not part of a ride's private chat. Whether the caller is *this*
# ride's patient or driver is checked per ride in chat_service.open_chat.
require_participant = require_role("patient", "driver")


def _to_response(message) -> MessageResponse:
    return MessageResponse(
        id=message.id,
        ride_id=message.ride_id,
        sender=message.sender_role,
        body=message.body,
        created_at=message.created_at,
    )


@router.get("/{ride_id}/messages", response_model=MessageListResponse)
@limiter.limit("120/minute")
async def list_messages(
    request: Request,
    ride_id: UUID,
    after_id: Optional[int] = Query(default=None, ge=0, le=MAX_MESSAGE_ID),
    current_user: User = Depends(require_participant),
    db: AsyncSession = Depends(get_db),
):
    """The ride's messages, oldest first. Pass after_id to get only newer ones."""
    await chat_service.open_chat(db, current_user, ride_id)
    messages = await chat_service.list_messages(db, ride_id, after_id)
    return MessageListResponse(items=[_to_response(m) for m in messages])


@router.post("/{ride_id}/messages", response_model=MessageResponse, status_code=201)
@limiter.limit("30/minute")
async def send_message(
    request: Request,
    ride_id: UUID,
    body: MessageCreate,
    current_user: User = Depends(require_participant),
    db: AsyncSession = Depends(get_db),
):
    """Send a text message to the other person on this ride."""
    access = await chat_service.open_chat(db, current_user, ride_id)
    message = await chat_service.add_message(db, access, current_user, body.body)
    await chat_service.publish_message(message)
    await chat_service.tell_other_side(db, access)
    return _to_response(message)
