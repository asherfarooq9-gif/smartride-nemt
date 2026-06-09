from typing import Optional, List, Any, Dict
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from app.models.models import RideType, RideStatus


class EmergencyRideRequest(BaseModel):
    pickup_lat: float = Field(ge=-90, le=90)
    pickup_lng: float = Field(ge=-180, le=180)
    pickup_address: Optional[str] = None
    symptom_text: str = Field(min_length=1, max_length=2000)


class ScheduledRideRequest(BaseModel):
    pickup_lat: float = Field(ge=-90, le=90)
    pickup_lng: float = Field(ge=-180, le=180)
    pickup_address: Optional[str] = None
    scheduled_for: datetime

    @field_validator("scheduled_for")
    @classmethod
    def must_be_future(cls, v: datetime) -> datetime:
        from datetime import timezone
        if v.tzinfo is None:
            v = v.replace(tzinfo=timezone.utc)
        from datetime import datetime as dt
        if v <= dt.now(timezone.utc):
            raise ValueError("scheduled_for must be a future date")
        return v


class RideStatusUpdate(BaseModel):
    status: RideStatus
    cancel_reason: Optional[str] = None


class RateRideRequest(BaseModel):
    rating: float = Field(ge=1, le=5)
    comment: Optional[str] = Field(default=None, max_length=500)


class RideResponse(BaseModel):
    id: UUID
    patient_id: UUID
    driver_id: Optional[UUID] = None
    hospital_id: Optional[UUID] = None
    ride_type: RideType
    status: RideStatus
    pickup_lat: float
    pickup_lng: float
    pickup_address: Optional[str] = None
    scheduled_for: Optional[datetime] = None
    requested_at: datetime
    driver_assigned_at: Optional[datetime] = None
    pickup_at: Optional[datetime] = None
    arrived_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    cancelled_at: Optional[datetime] = None
    cancel_reason: Optional[str] = None
    estimated_fare_pkr: Optional[float] = None
    final_fare_pkr: Optional[float] = None
    patient_rating: Optional[float] = None
    rating_comment: Optional[str] = None

    model_config = {"from_attributes": True}


class RideDetailResponse(RideResponse):
    patient: Optional[Dict[str, Any]] = None
    driver: Optional[Dict[str, Any]] = None
    hospital: Optional[Dict[str, Any]] = None
    triage: Optional[Dict[str, Any]] = None


class RideListResponse(BaseModel):
    items: List[RideResponse]
    total: int
