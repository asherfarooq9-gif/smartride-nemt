"""Internet calls: the relay credentials for one ride's call."""

from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.models import User
from app.routers.chat import require_participant
from app.routers.rides import limiter
from app.services import call_service, chat_service

router = APIRouter()


@router.get("/{ride_id}/call/ice-servers")
@limiter.limit("30/minute")
async def get_ice_servers(
    request: Request,
    ride_id: UUID,
    current_user: User = Depends(require_participant),
    db: AsyncSession = Depends(get_db),
):
    """Relay servers and a login that expires in minutes, for this person only.

    Same rule as the chat: the ride's own patient or driver, while the ride is live.
    """
    await chat_service.open_chat(db, current_user, ride_id)
    return call_service.ice_servers(str(current_user.id))
