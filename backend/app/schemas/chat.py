from datetime import datetime
from typing import List, Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

MAX_MESSAGE_LENGTH = 500


class MessageCreate(BaseModel):
    body: str = Field(max_length=MAX_MESSAGE_LENGTH * 2)

    @field_validator("body")
    @classmethod
    def _plain_text(cls, value: str) -> str:
        # Stored and shown as plain text; the apps never render it as markup.
        value = value.strip()
        if not value:
            raise ValueError("Message cannot be empty")
        if len(value) > MAX_MESSAGE_LENGTH:
            raise ValueError(f"Message is longer than {MAX_MESSAGE_LENGTH} characters")
        return value


class MessageResponse(BaseModel):
    id: int
    ride_id: UUID
    sender: Literal["patient", "driver"]
    body: str
    created_at: datetime


class MessageListResponse(BaseModel):
    items: List[MessageResponse]
