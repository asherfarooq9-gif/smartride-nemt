from typing import Optional

from pydantic import BaseModel


class ErrorResponse(BaseModel):
    detail: str
    code: str = "error"
    # Correlates a user-visible error with the server log / Sentry event.
    trace_id: Optional[str] = None
