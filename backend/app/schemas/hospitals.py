from typing import Optional, List
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel


class HospitalPublicResponse(BaseModel):
    """Hospital fields safe to expose to unauthenticated callers.

    Deliberately excludes `fhir_endpoint` and `coordinator_phone`: the first is
    internal integration infrastructure and the second is a staff contact
    number, neither of which patients need. See `HospitalResponse` for the
    admin-only view.
    """

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
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class HospitalResponse(HospitalPublicResponse):
    """Full hospital record, including internal fields. Admin routes only."""

    fhir_endpoint: Optional[str] = None
    coordinator_phone: Optional[str] = None


class HospitalCreate(BaseModel):
    name: str
    address: str
    city: str
    lat: float
    lng: float
    phone: Optional[str] = None
    specialties: List[str] = []
    ed_capacity: int = 50
    fhir_endpoint: Optional[str] = None
    coordinator_phone: Optional[str] = None


class HospitalUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    phone: Optional[str] = None
    specialties: Optional[List[str]] = None
    ed_capacity: Optional[int] = None
    ed_current_load: Optional[int] = None
    fhir_endpoint: Optional[str] = None
    coordinator_phone: Optional[str] = None
    is_active: Optional[bool] = None


class HospitalListResponse(BaseModel):
    items: List[HospitalPublicResponse]
    total: int


class HospitalAdminListResponse(BaseModel):
    items: List[HospitalResponse]
    total: int
