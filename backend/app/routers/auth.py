from datetime import datetime, timezone
from math import ceil

from fastapi import APIRouter, Depends, HTTPException, Request, status
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
from app.models.models import User, Patient, Driver, UserRole
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, RefreshResponse
from fastapi.security import HTTPAuthorizationCredentials

router = APIRouter()
limiter = Limiter(key_func=get_remote_address)


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register(request: Request, body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # #1 Block admin self-registration
    if body.role == UserRole.admin:
        raise HTTPException(status_code=403, detail="Admin accounts cannot be self-registered")

    result = await db.execute(select(User).where(User.phone == body.phone))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone already registered")

    if body.role == UserRole.driver:
        for field in ("license_no", "vehicle_plate", "vehicle_type"):
            if not getattr(body, field):
                raise HTTPException(status_code=422, detail=f"{field} is required for drivers")

    user = User(
        phone=body.phone,
        password_hash=hash_password(body.password),
        role=body.role,
    )
    db.add(user)
    await db.flush()

    if body.role == UserRole.patient:
        db.add(Patient(user_id=user.id, full_name=body.full_name))
    elif body.role == UserRole.driver:
        db.add(Driver(
            user_id=user.id,
            full_name=body.full_name,
            license_no=body.license_no,
            vehicle_plate=body.vehicle_plate,
            vehicle_type=body.vehicle_type,
        ))

    await db.commit()

    token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return TokenResponse(access_token=token, role=user.role.value, user_id=str(user.id))


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(request: Request, body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.phone == body.phone))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account disabled")

    token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return TokenResponse(access_token=token, role=user.role.value, user_id=str(user.id))


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
async def refresh_token(
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

    new_token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return RefreshResponse(access_token=new_token)
