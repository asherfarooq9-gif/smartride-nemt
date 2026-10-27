from typing import Optional, List
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field, field_validator, model_serializer
from app.models.models import RideType, RideStatus

# Free text from clients is bounded so one request cannot store megabytes.
MAX_ADDRESS_LENGTH = 500
MAX_REASON_LENGTH = 500


class EmergencyRideRequest(BaseModel):
    pickup_lat: float = Field(ge=-90, le=90)
    pickup_lng: float = Field(ge=-180, le=180)
    pickup_address: Optional[str] = Field(default=None, max_length=MAX_ADDRESS_LENGTH)
    symptom_text: str = Field(min_length=1, max_length=2000)


class ScheduledRideRequest(BaseModel):
    pickup_lat: float = Field(ge=-90, le=90)
    pickup_lng: float = Field(ge=-180, le=180)
    pickup_address: Optional[str] = Field(default=None, max_length=MAX_ADDRESS_LENGTH)
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
    cancel_reason: Optional[str] = Field(default=None, max_length=MAX_REASON_LENGTH)


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
    # Populated only where the hospital relation is loaded (e.g. /pending);
    # a raw hospital_id is meaningless to a driver deciding on a ride.
    hospital_name: Optional[str] = None

    model_config = {"from_attributes": True}


class RidePatientInfo(BaseModel):
    full_name: str
    # None once the ride is over and the viewer is the driver (see _patient_info).
    phone: Optional[str] = None
    mobility_needs: Optional[str] = None


class RideDriverInfo(BaseModel):
    full_name: str
    phone: str
    vehicle_plate: str
    vehicle_type: str


class RideHospitalInfo(BaseModel):
    name: str
    address: str
    city: str


class RideTriageInfo(BaseModel):
    predicted_specialty: str
    confidence_score: float
    severity_level: str
    # Raw complaint text is PHI: only the owning patient and admins get it. For
    # everyone else the key is absent from the payload, not null.
    symptom_text: Optional[str] = None

    @model_serializer(mode="wrap")
    def _omit_missing_symptom_text(self, handler):
        data = handler(self)
        if data.get("symptom_text") is None:
            data.pop("symptom_text", None)
        return data


class RideDetailResponse(RideResponse):
    patient: Optional[RidePatientInfo] = None
    driver: Optional[RideDriverInfo] = None
    hospital: Optional[RideHospitalInfo] = None
    triage: Optional[RideTriageInfo] = None


class RideListResponse(BaseModel):
    items: List[RideResponse]
    total: int
