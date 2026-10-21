from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from app.models.models import DriverStatus


class DriverResponse(BaseModel):
    id: str
    phone: str
    full_name: str
    license_no: str
    vehicle_plate: str
    vehicle_type: str
    is_verified: bool
    status: DriverStatus
    wallet_balance_pkr: float = 0.0
    current_lat: Optional[float] = None
    current_lng: Optional[float] = None
    last_seen_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}


MAX_TOPUP_PKR = 100_000


class WalletTopUpRequest(BaseModel):
    # allow_inf_nan=False: NaN passes every `<= 0` check and would poison the balance.
    amount_pkr: float = Field(ge=0, le=MAX_TOPUP_PKR, allow_inf_nan=False)
    payment_method: str = Field(max_length=30)  # jazzcash | easypaisa | bank | card
    plan_id: Optional[str] = Field(
        default=None, max_length=30
    )  # starter | standard | pro


class EarningsRide(BaseModel):
    id: str
    pickup_address: Optional[str] = None
    hospital_name: Optional[str] = None
    completed_at: Optional[str] = None
    fare_pkr: float
    ride_type: str


class EarningsResponse(BaseModel):
    total_earned_pkr: float
    ride_count: int
    rides: List[EarningsRide]


class WalletTransaction(BaseModel):
    id: str
    type: str  # topup | commission_deduction
    amount_pkr: float
    description: str
    created_at: datetime


class WalletResponse(BaseModel):
    balance_pkr: float
    commission_rate: float
    plan: str
    low_balance: bool
    weekly_commission_paid: float
    weekly_net_earnings: float
    transactions: List[WalletTransaction]


class DriverUpdate(BaseModel):
    full_name: Optional[str] = Field(default=None, max_length=100)
    vehicle_type: Optional[str] = Field(default=None, max_length=50)

    @field_validator("full_name", "vehicle_type")
    @classmethod
    def not_null(cls, v):
        # Omitting a field is fine (exclude_unset); an explicit null would hit a
        # NOT NULL column.
        if v is None:
            raise ValueError("cannot be null")
        return v


class DriverStatusUpdate(BaseModel):
    status: DriverStatus


class LocationUpdate(BaseModel):
    # Range checks also reject NaN and +/-inf, which fail every comparison.
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class DriverListResponse(BaseModel):
    items: List[DriverResponse]
    total: int
    page: int
