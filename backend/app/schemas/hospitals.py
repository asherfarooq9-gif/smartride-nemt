from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel


class HospitalResponse(BaseModel):
    id: str
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
    items: List[HospitalResponse]
    total: int
