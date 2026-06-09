from typing import Optional, List
from datetime import datetime
import uuid
from pydantic import BaseModel
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


class WalletTopUpRequest(BaseModel):
    amount_pkr: float
    payment_method: str  # jazzcash | easypaisa | bank | card
    plan_id: Optional[str] = None  # starter | standard | pro


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
    full_name: Optional[str] = None
    vehicle_type: Optional[str] = None


class DriverStatusUpdate(BaseModel):
    status: DriverStatus


class LocationUpdate(BaseModel):
    lat: float
    lng: float


class DriverListResponse(BaseModel):
    items: List[DriverResponse]
    total: int
    page: int
