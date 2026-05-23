from typing import Optional
from pydantic import BaseModel, field_validator
from app.models.models import UserRole


class RegisterRequest(BaseModel):
    phone: str
    password: str
    role: UserRole
    full_name: str
    # driver-only
    license_no: Optional[str] = None
    vehicle_plate: Optional[str] = None
    vehicle_type: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def phone_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("phone is required")
        return v

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("password must be at least 6 characters")
        return v


class LoginRequest(BaseModel):
    phone: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: str


class RefreshResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
