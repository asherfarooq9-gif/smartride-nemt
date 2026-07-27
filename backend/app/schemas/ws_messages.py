"""
Typed message contracts for the two WebSocket endpoints in
app.routers.ws (/ws/driver/{ride_id} and /ws/ride/{ride_id}).

Mirrored on the mobile side in
packages/smartride_core/lib/src/models/ws_messages.dart — keep both in sync
when this file changes; there is no shared codegen between the two.
"""

from typing import Literal

from pydantic import BaseModel, Field


class WSAuthMessage(BaseModel):
    """First frame the client must send on every WS connection."""

    token: str


class DriverLocationMessage(BaseModel):
    """Sent repeatedly by the driver app while streaming GPS."""

    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class DriverLocationAck(BaseModel):
    """Reply to a valid DriverLocationMessage."""

    ack: Literal[True] = True
    lat: float
    lng: float


class WSErrorMessage(BaseModel):
    error: str


class LocationBroadcast(BaseModel):
    """Forwarded verbatim to patient/admin watchers on /ws/ride/{ride_id}."""

    lat: float
    lng: float


class RideEndedMessage(BaseModel):
    """Sent once, then the connection is closed by the server."""

    event: Literal["ride_ended"] = "ride_ended"
    status: str
