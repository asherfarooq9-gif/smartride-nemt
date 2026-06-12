from datetime import datetime, timezone
from math import ceil

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from jose import JWTError, jwt
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.core.database import get_db
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    get_current_user,
    bearer_scheme,
)
from app.core.redis_client import block_token
from app.models.models import User, Patient, Driver, UserRole, UserRoleLink
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    TokenResponse,
    RefreshResponse,
    AddRoleRequest,
    SwitchRoleRequest,
    MeResponse,
)
from fastapi.security import HTTPAuthorizationCredentials

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)

_DRIVER_FIELDS = ("license_no", "vehicle_plate", "vehicle_type")


def _make_token(user: User, roles: list[str], active_role: str) -> str:
    # `role` claim kept for backward-compat; `roles` carries full membership.
    return create_access_token(
        {"sub": str(user.id), "role": active_role, "roles": roles}
    )


async def _held_roles(db: AsyncSession, user_id) -> list[str]:
    """Authoritative role membership read straight from user_roles."""
    res = await db.execute(
        select(UserRoleLink.role).where(UserRoleLink.user_id == user_id)
    )
    return sorted(r.value for r in res.scalars().all())


def _require_driver_fields(body) -> None:
    for field in _DRIVER_FIELDS:
        if not getattr(body, field):
            raise HTTPException(
                status_code=422, detail=f"{field} is required for drivers"
            )


@router.post(
    "/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED
)
@limiter.limit("5/minute")
async def register(
    request: Request, body: RegisterRequest, db: AsyncSession = Depends(get_db)
):
    if UserRole.admin in body.roles:
        raise HTTPException(
            status_code=403, detail="Admin accounts cannot be self-registered"
        )

    result = await db.execute(select(User).where(User.phone == body.phone))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone already registered")

    if UserRole.driver in body.roles:
        _require_driver_fields(body)

    active = body.active_role or body.roles[0]
    if active not in body.roles:
        raise HTTPException(
            status_code=422, detail="active_role must be one of the requested roles"
        )

    user = User(
        phone=body.phone,
        password_hash=hash_password(body.password),
        role=active,
    )
    db.add(user)
    await db.flush()

    for role in body.roles:
        db.add(UserRoleLink(user_id=user.id, role=role))
        if role == UserRole.patient:
            db.add(Patient(user_id=user.id, full_name=body.full_name))
        elif role == UserRole.driver:
            db.add(
                Driver(
                    user_id=user.id,
                    full_name=body.full_name,
                    license_no=body.license_no,
                    vehicle_plate=body.vehicle_plate,
                    vehicle_type=body.vehicle_type,
                )
            )

    await db.commit()

    roles = sorted(r.value for r in body.roles)
    return TokenResponse(
        access_token=_make_token(user, roles, active.value),
        roles=roles,
        active_role=active.value,
        role=active.value,
        user_id=str(user.id),
    )


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(
    request: Request, body: LoginRequest, db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(User).where(User.phone == body.phone))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account disabled")

    roles = await _held_roles(db, user.id)
    active = body.active_role.value if body.active_role else user.role.value
    if active not in roles:
        raise HTTPException(status_code=403, detail="You do not have that role")

    if active != user.role.value:
        user.role = UserRole(active)
        await db.commit()

    return TokenResponse(
        access_token=_make_token(user, roles, active),
        roles=roles,
        active_role=active,
        role=active,
        user_id=str(user.id),
    )


@router.post("/add-role", response_model=TokenResponse)
@limiter.limit("5/minute")
async def add_role(
    request: Request,
    body: AddRoleRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """inDrive 'Become a driver/patient' — add a role + profile to this account."""
    if body.role == UserRole.admin:
        raise HTTPException(status_code=403, detail="Cannot add admin role")
    if body.role.value in current_user.held_roles:
        raise HTTPException(status_code=400, detail="Account already has this role")

    if body.role == UserRole.driver:
        _require_driver_fields(body)
        # carry the display name over from the existing patient profile, if any
        existing = (
            await db.execute(select(Patient).where(Patient.user_id == current_user.id))
        ).scalar_one_or_none()
        db.add(
            Driver(
                user_id=current_user.id,
                full_name=(existing.full_name if existing else ""),
                license_no=body.license_no,
                vehicle_plate=body.vehicle_plate,
                vehicle_type=body.vehicle_type,
            )
        )
    elif body.role == UserRole.patient:
        existing = (
            await db.execute(select(Driver).where(Driver.user_id == current_user.id))
        ).scalar_one_or_none()
        db.add(
            Patient(
                user_id=current_user.id,
                full_name=(existing.full_name if existing else ""),
            )
        )

    db.add(UserRoleLink(user_id=current_user.id, role=body.role))
    await db.commit()

    roles = await _held_roles(db, current_user.id)
    return TokenResponse(
        access_token=_make_token(current_user, roles, current_user.role.value),
        roles=roles,
        active_role=current_user.role.value,
        role=current_user.role.value,
        user_id=str(current_user.id),
    )


@router.post("/switch-role", response_model=TokenResponse)
async def switch_role(
    body: SwitchRoleRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Flip the active portal. Account must already hold the target role."""
    target = body.active_role.value
    if target not in current_user.held_roles:
        raise HTTPException(status_code=403, detail="Account does not have that role")

    if target != current_user.role.value:
        current_user.role = body.active_role
        await db.commit()

    roles = await _held_roles(db, current_user.id)
    return TokenResponse(
        access_token=_make_token(current_user, roles, target),
        roles=roles,
        active_role=target,
        role=target,
        user_id=str(current_user.id),
    )


@router.get("/me", response_model=MeResponse)
async def me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    roles = await _held_roles(db, current_user.id)

    patient = (
        await db.execute(select(Patient).where(Patient.user_id == current_user.id))
    ).scalar_one_or_none()
    driver = (
        await db.execute(select(Driver).where(Driver.user_id == current_user.id))
    ).scalar_one_or_none()

    return MeResponse(
        user_id=str(current_user.id),
        phone=current_user.phone,
        roles=roles,
        active_role=current_user.role.value,
        has_patient_profile=patient is not None,
        has_driver_profile=driver is not None,
        driver_verified=bool(driver.is_verified) if driver else False,
    )


class _FcmTokenRequest(BaseModel):
    fcm_token: str = Field(max_length=256)


@router.post("/fcm-token", status_code=status.HTTP_204_NO_CONTENT)
async def register_fcm_token(
    body: _FcmTokenRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.fcm_token:
        current_user.fcm_token = body.fcm_token
        await db.commit()


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    _user: User = Depends(get_current_user),
):
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        jti: str = payload.get("jti", "")
        exp: int = payload.get("exp", 0)
        if jti:
            remaining = max(1, ceil(exp - datetime.now(timezone.utc).timestamp()))
            await block_token(jti, remaining)
    except JWTError:
        pass


@router.post("/refresh", response_model=RefreshResponse)
@limiter.limit("20/minute")
async def refresh_token(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
):
    """Exchange a valid non-expired token for a fresh one, revoking the old token."""
    user = await get_current_user(credentials=credentials, db=db)
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        jti = payload.get("jti", "")
        exp = payload.get("exp", 0)
        remaining = max(0, int(exp - datetime.now(timezone.utc).timestamp()))
        if jti and remaining > 0:
            await block_token(jti, remaining)
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    roles = await _held_roles(db, user.id)
    new_token = _make_token(user, roles, user.role.value)
    return RefreshResponse(access_token=new_token)
