from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel
from app.models.models import RideType, RideStatus


class EmergencyRideRequest(BaseModel):
    pickup_lat: float
    pickup_lng: float
    pickup_address: Optional[str] = None
    symptom_text: str


class ScheduledRideRequest(BaseModel):
    pickup_lat: float
    pickup_lng: float
    pickup_address: Optional[str] = None
    scheduled_for: datetime


class RideStatusUpdate(BaseModel):
    status: RideStatus


class RideResponse(BaseModel):
    id: str
    patient_id: str
    driver_id: Optional[str] = None
    hospital_id: Optional[str] = None
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

    model_config = {"from_attributes": True}


class RideListResponse(BaseModel):
    items: List[RideResponse]
    total: int
