import ipaddress
from typing import Optional, List
from urllib.parse import urlsplit
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field, field_validator


def _public_https_url(value: Optional[str]) -> Optional[str]:
    """The server POSTs patient data to this URL, so it must be public HTTPS.

    Blocks IP literals in private, loopback and link-local ranges and obvious
    internal hostnames. A hostname that merely resolves to a private address is
    not caught here (no DNS lookups at validation time).
    """
    if not value:
        return value
    parts = urlsplit(value)
    host = parts.hostname
    if parts.scheme != "https" or not host:
        raise ValueError("fhir_endpoint must be an https URL")
    if host == "localhost" or host.endswith((".local", ".internal", ".localhost")):
        raise ValueError("fhir_endpoint must be a public host")
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return value
    if not ip.is_global:
        raise ValueError("fhir_endpoint must be a public host")
    return value


class HospitalResponse(BaseModel):
    id: UUID
    name: str
    address: str
    city: str
    lat: float
    lng: float
    phone: Optional[str] = None
    specialties: List[str]
    ed_capacity: int
    ed_current_load: int
    fhir_endpoint: Optional[str] = None
    coordinator_phone: Optional[str] = None
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class HospitalCreate(BaseModel):
    name: str = Field(max_length=200)
    address: str
    city: str = Field(max_length=100)
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    phone: Optional[str] = Field(default=None, max_length=20)
    specialties: List[str] = []
    ed_capacity: int = Field(default=50, ge=0)
    fhir_endpoint: Optional[str] = Field(default=None, max_length=500)
    coordinator_phone: Optional[str] = Field(default=None, max_length=20)

    _check_fhir = field_validator("fhir_endpoint")(_public_https_url)


class HospitalUpdate(BaseModel):
    name: Optional[str] = Field(default=None, max_length=200)
    address: Optional[str] = None
    city: Optional[str] = Field(default=None, max_length=100)
    lat: Optional[float] = Field(default=None, ge=-90, le=90)
    lng: Optional[float] = Field(default=None, ge=-180, le=180)
    phone: Optional[str] = Field(default=None, max_length=20)
    specialties: Optional[List[str]] = None
    ed_capacity: Optional[int] = Field(default=None, ge=0)
    ed_current_load: Optional[int] = Field(default=None, ge=0)
    fhir_endpoint: Optional[str] = Field(default=None, max_length=500)
    coordinator_phone: Optional[str] = Field(default=None, max_length=20)
    is_active: Optional[bool] = None

    _check_fhir = field_validator("fhir_endpoint")(_public_https_url)


class HospitalListResponse(BaseModel):
    items: List[HospitalResponse]
    total: int
