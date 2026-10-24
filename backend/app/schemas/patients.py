from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field, field_validator


class PatientResponse(BaseModel):
    id: str
    phone: str
    full_name: str
    date_of_birth: Optional[datetime] = None
    mobility_needs: Optional[str] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None
    created_at: datetime
    total_rides: Optional[int] = None

    model_config = {"from_attributes": True}


class PatientUpdate(BaseModel):
    full_name: Optional[str] = Field(default=None, max_length=100)
    date_of_birth: Optional[datetime] = None
    mobility_needs: Optional[str] = Field(default=None, max_length=500)
    emergency_contact_name: Optional[str] = Field(default=None, max_length=100)
    emergency_contact_phone: Optional[str] = Field(default=None, max_length=20)

    @field_validator("full_name")
    @classmethod
    def full_name_not_null(cls, v):
        # Omitting the field is fine (exclude_unset); an explicit null would
        # hit the NOT NULL column.
        if v is None:
            raise ValueError("full_name cannot be null")
        return v


class PatientListResponse(BaseModel):
    items: List[PatientResponse]
    total: int
