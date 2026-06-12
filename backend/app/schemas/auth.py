from typing import Optional, List
from pydantic import BaseModel, field_validator, model_validator
from app.models.models import UserRole


class RegisterRequest(BaseModel):
    phone: str
    password: str
    full_name: str
    # New multi-role API: one or more initial roles ("both" == ["patient","driver"]).
    roles: Optional[List[UserRole]] = None
    # Legacy single-role API (still accepted; normalised into `roles`).
    role: Optional[UserRole] = None
    # which portal to open first; defaults to the first requested role
    active_role: Optional[UserRole] = None
    # driver-only profile fields (required if "driver" is among roles)
    license_no: Optional[str] = None
    vehicle_plate: Optional[str] = None
    vehicle_type: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def phone_not_empty(cls, v: str) -> str:
        import re

        v = v.strip()
        if not v:
            raise ValueError("phone is required")
        if not re.match(r"^\+?[0-9]{7,15}$", v):
            raise ValueError("phone must be 7–15 digits, optionally prefixed with +")
        return v

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("password must be at least 8 characters")
        return v

    @model_validator(mode="after")
    def _normalize_roles(self):
        roles = self.roles or ([self.role] if self.role else [])
        if not roles:
            raise ValueError("at least one role is required (use `roles` or `role`)")
        # de-dupe while preserving order
        seen: set = set()
        out: List[UserRole] = []
        for r in roles:
            if r not in seen:
                seen.add(r)
                out.append(r)
        self.roles = out
        return self


class AddRoleRequest(BaseModel):
    role: UserRole
    license_no: Optional[str] = None
    vehicle_plate: Optional[str] = None
    vehicle_type: Optional[str] = None


class SwitchRoleRequest(BaseModel):
    active_role: UserRole


class LoginRequest(BaseModel):
    phone: str
    password: str
    active_role: Optional[UserRole] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    roles: List[str]
    active_role: str
    # legacy field == active_role, kept so older clients keep working
    role: str
    user_id: str


class RefreshResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class MeResponse(BaseModel):
    user_id: str
    phone: str
    roles: List[str]
    active_role: str
    has_patient_profile: bool
    has_driver_profile: bool
    driver_verified: bool
