from typing import Optional, List
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field, field_validator

from app.core.safe_url import UnsafeUrlError, check_public_hostname_url


def _public_https_url(value: Optional[str]) -> Optional[str]:
    """The server POSTs patient data to this URL, so it must be an https URL with a
    real DNS name. IP literals in any notation (dotted, integer, hex, octal, IPv6)
    and internal names are refused here; the address the name resolves to is
    checked again at send time (app.core.safe_url.resolve_public_ip), which is what
    catches names like 127.0.0.1.nip.io.
    """
    if not value:
        return value
    try:
        return check_public_hostname_url(value, schemes=("https",))
    except UnsafeUrlError as exc:
        raise ValueError(f"fhir_endpoint rejected: {exc}") from exc


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
