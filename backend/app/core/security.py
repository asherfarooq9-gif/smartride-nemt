import asyncio
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from passlib.context import CryptContext
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.core.database import get_db

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
# auto_error=False so a *missing* Authorization header yields our own
# 401 (semantically correct for "not authenticated") rather than the
# library default of 403 (which should mean "authenticated but forbidden").
bearer_scheme = HTTPBearer(auto_error=False)


# Checked against when the phone is unknown, so a miss costs as much as a wrong
# password and response time does not reveal which phones are registered.
DUMMY_PASSWORD_HASH = pwd_context.hash("not-a-real-password")


def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
):
    """The signed-in user, or None for anonymous or invalid credentials."""
    if credentials is None:
        return None
    try:
        return await get_current_user(credentials=credentials, db=db)
    except HTTPException:
        return None


def require_metrics_access(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
) -> None:
    """/metrics exposes traffic and error internals: scraper token only (open in DEBUG)."""
    if settings.DEBUG:
        return
    if credentials is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    expected = settings.METRICS_TOKEN
    if not expected or not secrets.compare_digest(credentials.credentials, expected):
        raise HTTPException(status_code=403, detail="Forbidden")


async def hash_password_async(plain: str) -> str:
    """bcrypt is CPU-bound (~100ms+); keep it off the event loop."""
    return await asyncio.to_thread(hash_password, plain)


async def verify_password_async(plain: str, hashed: str) -> bool:
    return await asyncio.to_thread(verify_password, plain, hashed)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    payload = data.copy()
    now = datetime.now(timezone.utc)
    expire = now + (expires_delta or timedelta(minutes=settings.JWT_EXPIRE_MINUTES))
    payload["exp"] = expire
    payload["iat"] = now
    payload["jti"] = str(uuid.uuid4())
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    """Verify signature, algorithm and expiry. A token with no exp/sub/jti is invalid,
    otherwise one minted without an expiry would be valid forever."""
    return jwt.decode(
        token,
        settings.SECRET_KEY,
        algorithms=[settings.JWT_ALGORITHM],
        options={"require": ["exp", "sub", "jti"]},
    )


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
):
    from app.models.models import User
    from app.core.redis_client import is_token_blocked

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        payload = decode_token(credentials.credentials)
        user_id: str = payload.get("sub")
        jti: str = payload.get("jti")
        if user_id is None or jti is None:
            raise credentials_exception
    except jwt.PyJWTError:
        raise credentials_exception

    if await is_token_blocked(jti):
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise credentials_exception
    # Tokens issued before the version existed carry none and count as version 0.
    if int(payload.get("tv", 0)) != user.token_version:
        raise credentials_exception
    return user


def require_role(*roles: str):
    async def checker(current_user=Depends(get_current_user)):
        # Membership check: a multi-role account passes if it HOLDS any required
        # role, regardless of which portal is currently active.
        if not (set(roles) & current_user.held_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions"
            )
        return current_user

    return checker


require_patient = require_role("patient")
require_driver = require_role("driver")
require_admin = require_role("admin")
