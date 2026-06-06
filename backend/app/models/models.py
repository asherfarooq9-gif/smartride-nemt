import uuid
from datetime import datetime
from typing import Optional, List
from sqlalchemy import (
    String, Boolean, DateTime, ForeignKey, Text, Numeric,
    Integer, Enum as SAEnum, ARRAY, JSON, Index
)
from sqlalchemy.dialects.postgresql import UUID, JSONB, DOUBLE_PRECISION
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.core.database import Base

import enum


class UserRole(str, enum.Enum):
    patient = "patient"
    driver = "driver"
    admin = "admin"


class RideType(str, enum.Enum):
    emergency = "emergency"
    scheduled = "scheduled"


class RideStatus(str, enum.Enum):
    pending = "pending"
    driver_assigned = "driver_assigned"
    driver_en_route = "driver_en_route"
    patient_picked_up = "patient_picked_up"
    arrived_at_hospital = "arrived_at_hospital"
    completed = "completed"
    cancelled = "cancelled"


class DriverStatus(str, enum.Enum):
    available = "available"
    busy = "busy"
    offline = "offline"


class Specialty(str, enum.Enum):
    cardiology = "cardiology"
    neurology = "neurology"
    orthopedics = "orthopedics"
    obstetrics = "obstetrics"
    pediatrics = "pediatrics"
    psychiatry = "psychiatry"
    oncology = "oncology"
    nephrology = "nephrology"
    pulmonology = "pulmonology"
    gastroenterology = "gastroenterology"
    ophthalmology = "ophthalmology"
    ent = "ent"
    dermatology = "dermatology"
    general_emergency = "general_emergency"


class SeverityLevel(str, enum.Enum):
    one = "1"
    two = "2"
    three = "3"
    four = "4"
    five = "5"


# ─── USER ─────────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id:            Mapped[uuid.UUID]  = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phone:         Mapped[str]        = mapped_column(String(20), unique=True, nullable=False)
    password_hash: Mapped[str]        = mapped_column(Text, nullable=False)
    # `role` is the user's *active* role (the portal they're currently in).
    # The full set of roles the account holds lives in `user_roles`.
    role:          Mapped[UserRole]   = mapped_column(SAEnum(UserRole, name="user_role", create_type=False), nullable=False)
    is_active:     Mapped[bool]             = mapped_column(Boolean, default=True)
    fcm_token:     Mapped[Optional[str]]    = mapped_column(Text, nullable=True)
    created_at:    Mapped[datetime]         = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at:    Mapped[datetime]         = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    patient: Mapped[Optional["Patient"]] = relationship("Patient", back_populates="user", uselist=False)
    driver:  Mapped[Optional["Driver"]]  = relationship("Driver",  back_populates="user", uselist=False)
    roles:   Mapped[List["UserRoleLink"]] = relationship(
        "UserRoleLink", back_populates="user", lazy="selectin", cascade="all, delete-orphan"
    )

    @property
    def held_roles(self) -> set[str]:
        """All roles this account possesses (membership), not just the active one."""
        return {link.role.value for link in self.roles}


# ─── USER ROLE LINK (multi-role: one account can be patient AND driver) ──────────

class UserRoleLink(Base):
    __tablename__ = "user_roles"

    id:      Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role:    Mapped[UserRole]  = mapped_column(SAEnum(UserRole, name="user_role", create_type=False), nullable=False)

    __table_args__ = (
        Index("ix_user_roles_user_id", "user_id"),
        Index("uq_user_roles_user_role", "user_id", "role", unique=True),
    )

    user: Mapped["User"] = relationship("User", back_populates="roles")


# ─── PATIENT ──────────────────────────────────────────────────────────────────

class Patient(Base):
    __tablename__ = "patients"

    id:                      Mapped[uuid.UUID]     = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id:                 Mapped[uuid.UUID]     = mapped_column(ForeignKey("users.id"), unique=True)
    full_name:               Mapped[str]           = mapped_column(String(100))
    date_of_birth:           Mapped[Optional[datetime]] = mapped_column(DateTime)
    mobility_needs:          Mapped[Optional[str]] = mapped_column(Text)
    emergency_contact_name:  Mapped[Optional[str]] = mapped_column(String(100))
    emergency_contact_phone: Mapped[Optional[str]] = mapped_column(String(20))
    created_at:              Mapped[datetime]      = mapped_column(DateTime(timezone=True), server_default=func.now())

    user:  Mapped["User"]        = relationship("User", back_populates="patient")
    rides: Mapped[List["Ride"]]  = relationship("Ride", back_populates="patient")


# ─── DRIVER ───────────────────────────────────────────────────────────────────

class Driver(Base):
    __tablename__ = "drivers"

    id:            Mapped[uuid.UUID]          = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id:       Mapped[uuid.UUID]          = mapped_column(ForeignKey("users.id"), unique=True)
    full_name:     Mapped[str]                = mapped_column(String(100))
    license_no:    Mapped[str]                = mapped_column(String(50), unique=True)
    vehicle_plate: Mapped[str]                = mapped_column(String(20), unique=True)
    vehicle_type:  Mapped[str]                = mapped_column(String(50))
    is_verified:   Mapped[bool]               = mapped_column(Boolean, default=False)
    status:        Mapped[DriverStatus]       = mapped_column(SAEnum(DriverStatus, name="driver_status", create_type=False), default=DriverStatus.offline)
    current_lat:   Mapped[Optional[float]]    = mapped_column(DOUBLE_PRECISION)
    current_lng:   Mapped[Optional[float]]    = mapped_column(DOUBLE_PRECISION)
    last_seen_at:  Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    created_at:    Mapped[datetime]           = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_drivers_status", "status"),
        Index("ix_drivers_user_id", "user_id"),
    )

    user:  Mapped["User"]       = relationship("User", back_populates="driver")
    rides: Mapped[List["Ride"]] = relationship("Ride", back_populates="driver")


# ─── HOSPITAL ─────────────────────────────────────────────────────────────────

class Hospital(Base):
    __tablename__ = "hospitals"

    id:                Mapped[uuid.UUID]    = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name:              Mapped[str]          = mapped_column(String(200))
    address:           Mapped[str]          = mapped_column(Text)
    city:              Mapped[str]          = mapped_column(String(100))
    lat:               Mapped[float]        = mapped_column(DOUBLE_PRECISION)
    lng:               Mapped[float]        = mapped_column(DOUBLE_PRECISION)
    phone:             Mapped[Optional[str]] = mapped_column(String(20))
    specialties:       Mapped[list]         = mapped_column(JSON, default=list)
    ed_capacity:       Mapped[int]          = mapped_column(Integer, default=50)
    ed_current_load:   Mapped[int]          = mapped_column(Integer, default=0)
    fhir_endpoint:     Mapped[Optional[str]] = mapped_column(Text)
    coordinator_phone: Mapped[Optional[str]] = mapped_column(String(20))
    is_active:         Mapped[bool]         = mapped_column(Boolean, default=True)
    created_at:        Mapped[datetime]     = mapped_column(DateTime(timezone=True), server_default=func.now())


# ─── RIDE ─────────────────────────────────────────────────────────────────────

class Ride(Base):
    __tablename__ = "rides"

    id:                  Mapped[uuid.UUID]          = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    patient_id:          Mapped[uuid.UUID]           = mapped_column(ForeignKey("patients.id"))
    driver_id:           Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("drivers.id"))
    hospital_id:         Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("hospitals.id"))
    ride_type:           Mapped[RideType]             = mapped_column(SAEnum(RideType, name="ride_type", create_type=False))
    status:              Mapped[RideStatus]           = mapped_column(SAEnum(RideStatus, name="ride_status", create_type=False), default=RideStatus.pending)
    pickup_lat:          Mapped[float]                = mapped_column(DOUBLE_PRECISION)
    pickup_lng:          Mapped[float]                = mapped_column(DOUBLE_PRECISION)
    pickup_address:      Mapped[Optional[str]]        = mapped_column(Text)
    scheduled_for:       Mapped[Optional[datetime]]   = mapped_column(DateTime(timezone=True))
    requested_at:        Mapped[datetime]             = mapped_column(DateTime(timezone=True), server_default=func.now())
    driver_assigned_at:  Mapped[Optional[datetime]]   = mapped_column(DateTime(timezone=True))
    pickup_at:           Mapped[Optional[datetime]]   = mapped_column(DateTime(timezone=True))
    arrived_at:          Mapped[Optional[datetime]]   = mapped_column(DateTime(timezone=True))
    completed_at:        Mapped[Optional[datetime]]   = mapped_column(DateTime(timezone=True))
    cancelled_at:        Mapped[Optional[datetime]]   = mapped_column(DateTime(timezone=True))
    cancel_reason:       Mapped[Optional[str]]        = mapped_column(Text)
    estimated_fare_pkr:  Mapped[Optional[float]]      = mapped_column(Numeric(10, 2))
    final_fare_pkr:      Mapped[Optional[float]]      = mapped_column(Numeric(10, 2))
    created_at:          Mapped[datetime]             = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_rides_status", "status"),
        Index("ix_rides_ride_type", "ride_type"),
        Index("ix_rides_requested_at", "requested_at"),
        Index("ix_rides_patient_id", "patient_id"),
        Index("ix_rides_driver_id", "driver_id"),
    )

    patient:        Mapped["Patient"]              = relationship("Patient", back_populates="rides", lazy="noload")
    driver:         Mapped[Optional["Driver"]]     = relationship("Driver",  back_populates="rides", lazy="noload")
    hospital:       Mapped[Optional["Hospital"]]   = relationship("Hospital", foreign_keys=[hospital_id], lazy="noload")
    triage_events:  Mapped[List["TriageEvent"]]    = relationship("TriageEvent",  back_populates="ride")
    hospital_alerts: Mapped[List["HospitalAlert"]] = relationship("HospitalAlert", back_populates="ride")
    family_notifications: Mapped[List["FamilyNotification"]] = relationship("FamilyNotification", back_populates="ride")


# ─── TRIAGE EVENT ─────────────────────────────────────────────────────────────

class TriageEvent(Base):
    __tablename__ = "triage_events"

    id:                  Mapped[uuid.UUID]   = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ride_id:             Mapped[uuid.UUID]   = mapped_column(ForeignKey("rides.id", ondelete="CASCADE"))
    symptom_text:        Mapped[str]         = mapped_column(Text)
    predicted_specialty: Mapped[Specialty]   = mapped_column(SAEnum(Specialty, name="specialty", create_type=False))
    confidence_score:    Mapped[float]       = mapped_column(Numeric(5, 4))
    severity_level:      Mapped[SeverityLevel] = mapped_column(SAEnum(SeverityLevel, name="severity_level", create_type=False))
    rule_override:       Mapped[bool]        = mapped_column(Boolean, default=False)
    model_version:       Mapped[str]         = mapped_column(String(50))
    inference_ms:        Mapped[Optional[int]] = mapped_column(Integer)
    created_at:          Mapped[datetime]    = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        Index("ix_triage_ride_id", "ride_id"),
    )

    ride: Mapped["Ride"] = relationship("Ride", back_populates="triage_events")


# ─── HOSPITAL ALERT ───────────────────────────────────────────────────────────

class HospitalAlert(Base):
    __tablename__ = "hospital_alerts"

    id:          Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ride_id:     Mapped[uuid.UUID]        = mapped_column(ForeignKey("rides.id", ondelete="CASCADE"))
    hospital_id: Mapped[uuid.UUID]        = mapped_column(ForeignKey("hospitals.id"))
    channel:     Mapped[str]             = mapped_column(String(20))
    payload:     Mapped[Optional[dict]]  = mapped_column(JSONB)
    sent_at:     Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    status:      Mapped[str]             = mapped_column(String(20), default="pending")
    error_msg:   Mapped[Optional[str]]   = mapped_column(Text)

    ride: Mapped["Ride"] = relationship("Ride", back_populates="hospital_alerts")


# ─── FAMILY NOTIFICATION ──────────────────────────────────────────────────────

class FamilyNotification(Base):
    __tablename__ = "family_notifications"

    id:              Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ride_id:         Mapped[uuid.UUID]        = mapped_column(ForeignKey("rides.id", ondelete="CASCADE"))
    recipient_phone: Mapped[str]             = mapped_column(String(20))
    message_body:    Mapped[str]             = mapped_column(Text)
    twilio_sid:      Mapped[Optional[str]]   = mapped_column(String(100))
    sent_at:         Mapped[datetime]        = mapped_column(DateTime(timezone=True), server_default=func.now())
    status:          Mapped[str]             = mapped_column(String(20), default="pending")

    ride: Mapped["Ride"] = relationship("Ride", back_populates="family_notifications")


# ─── ANALYTICS HOURLY ─────────────────────────────────────────────────────────

class AnalyticsHourly(Base):
    __tablename__ = "analytics_hourly"

    id:                     Mapped[uuid.UUID]      = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    snapshot_hour:          Mapped[datetime]       = mapped_column(DateTime(timezone=True), nullable=False)
    city:                   Mapped[str]            = mapped_column(String(100), nullable=False)
    zone_id:                Mapped[Optional[str]]  = mapped_column(String(50))
    total_rides:            Mapped[int]            = mapped_column(Integer, default=0)
    emergency_rides:        Mapped[int]            = mapped_column(Integer, default=0)
    avg_eta_seconds:        Mapped[Optional[float]] = mapped_column(Numeric(8, 2))
    missed_appointments:    Mapped[int]            = mapped_column(Integer, default=0)
    driver_utilisation_pct: Mapped[Optional[float]] = mapped_column(Numeric(5, 2))
    created_at:             Mapped[datetime]       = mapped_column(DateTime(timezone=True), server_default=func.now())
