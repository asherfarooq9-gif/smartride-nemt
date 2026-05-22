from typing import Optional
from datetime import datetime
from pydantic import BaseModel


class PatientResponse(BaseModel):
    id: str
    phone: str
    full_name: str
    date_of_birth: Optional[datetime] = None
    mobility_needs: Optional[str] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class PatientUpdate(BaseModel):
    full_name: Optional[str] = None
    date_of_birth: Optional[datetime] = None
    mobility_needs: Optional[str] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
