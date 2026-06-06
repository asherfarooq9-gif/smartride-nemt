# SmartRide NEMT — System Design Document

**Project:** SmartRide — AI-Powered Non-Emergency Medical Transport  
**Pilot Region:** Islamabad / Rawalpindi, Pakistan  
**Version:** 1.0  
**Date:** June 2026

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Technology Stack](#3-technology-stack)
4. [Backend Design](#4-backend-design)
5. [Database Design](#5-database-design)
6. [AI Triage Service](#6-ai-triage-service)
7. [Mobile Application](#7-mobile-application)
8. [Admin Dashboard](#8-admin-dashboard)
9. [Real-Time Communication](#9-real-time-communication)
10. [Security Design](#10-security-design)
11. [API Reference](#11-api-reference)
12. [Deployment Architecture](#12-deployment-architecture)
13. [Emergency Dispatch Pipeline](#13-emergency-dispatch-pipeline)
14. [Data Flow Diagrams](#14-data-flow-diagrams)

---

## 1. Project Overview

### 1.1 Problem Statement

Pakistan's healthcare transport system lacks a coordinated, technology-driven solution for medical emergencies. Patients facing emergencies must manually call hospitals, find transport, and navigate to the correct facility — often without knowing which hospital has the required specialty or capacity. This delay costs lives.

### 1.2 Solution

SmartRide is an AI-powered NEMT platform that automates the full emergency transport pipeline:

1. Patient reports symptoms via mobile app
2. AI triage classifies the case and determines required medical specialty
3. System matches the nearest appropriate hospital based on specialty, ED capacity, and distance
4. Nearest verified driver is dispatched automatically
5. Family receives SMS notification; hospital receives pre-arrival alert
6. Patient tracks the driver in real time

### 1.3 Key Features

| Feature | Description |
|---------|-------------|
| AI Symptom Triage | ML model classifies symptoms into 14 medical specialties with ESI severity scoring (1–5) |
| Hospital Matching | Multi-factor scoring: distance (40%), ED wait (30%), specialty match (20%), outcome score (10%) |
| Driver Dispatch | Haversine-based nearest-driver assignment with atomic race-condition protection |
| Live Tracking | WebSocket-based real-time GPS streaming from driver to patient |
| Multi-Role Accounts | Single account holds patient + driver roles, switchable portals |
| Emergency Pipeline | Target end-to-end dispatch in under 60 seconds |
| Family Notifications | Automated Twilio SMS to emergency contact on dispatch |
| Hospital Pre-alerts | FHIR-compliant pre-arrival notifications to hospital coordinators |

---

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│                                                                 │
│   ┌─────────────────────┐        ┌──────────────────────────┐  │
│   │  Flutter Mobile App  │        │   Next.js Admin Dashboard│  │
│   │  (Patient + Driver)  │        │   (Hospital Mgmt, Stats) │  │
│   └──────────┬──────────┘        └────────────┬─────────────┘  │
└──────────────┼─────────────────────────────────┼───────────────┘
               │ HTTPS / WSS                     │ HTTPS
┌──────────────▼─────────────────────────────────▼───────────────┐
│                      SERVICE LAYER                              │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │              FastAPI Backend  (Port 8000)                │  │
│   │                                                          │  │
│   │  /auth  /patients  /drivers  /rides  /hospitals          │  │
│   │  /analytics  /ws (WebSocket)                            │  │
│   └──────────┬──────────────────────────────────────────────┘  │
│              │                                                  │
│   ┌──────────▼──────────┐    ┌─────────────────────────────┐   │
│   │  AI Triage Service  │    │   Celery Worker             │   │
│   │  (Port 8001)        │    │   (SMS + Hospital Alerts)   │   │
│   └─────────────────────┘    └─────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┬──┘
                                                               │
┌──────────────────────────────────────────────────────────────▼──┐
│                       DATA LAYER                                │
│                                                                 │
│   ┌─────────────────────┐        ┌──────────────────────────┐  │
│   │  PostgreSQL + PostGIS│        │        Redis             │  │
│   │  (Primary Database) │        │  (Cache + Pub/Sub +      │  │
│   │                     │        │   Token Blocklist)        │  │
│   └─────────────────────┘        └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **Flutter App** | Patient & driver portals; GPS streaming; real-time tracking |
| **FastAPI Backend** | REST API; business logic; auth; WebSocket gateway |
| **AI Triage Service** | Symptom classification; specialty prediction; severity scoring |
| **Celery Worker** | Async SMS dispatch; hospital FHIR pre-alerts |
| **PostgreSQL** | Persistent storage: users, rides, hospitals, analytics |
| **Redis** | JWT revocation blocklist; hospital list cache; location pub/sub |
| **Next.js Admin** | Hospital management; driver verification; analytics dashboard |

---

## 3. Technology Stack

### 3.1 Backend

| Category | Technology | Justification |
|----------|-----------|---------------|
| Framework | FastAPI 0.115 | Async-first, OpenAPI auto-docs, Pydantic validation |
| ORM | SQLAlchemy 2.0 (async) | Type-safe, async session support |
| Database driver | asyncpg | High-performance PostgreSQL async driver |
| Auth | python-jose + bcrypt | JWT tokens + secure password hashing |
| Cache / Pub-Sub | Redis (aioredis) | Token blocklist, hospital cache, WebSocket location |
| Task Queue | Celery + Redis | Async notifications without blocking request cycle |
| Rate Limiting | slowapi | Per-endpoint rate limits (auth: 5–10/min) |
| Validation | Pydantic v2 | Request/response schemas with field-level constraints |

### 3.2 Mobile App

| Category | Technology | Justification |
|----------|-----------|---------------|
| Framework | Flutter 3.x (Dart 3.4+) | Single codebase for iOS, Android, Web |
| State Management | Riverpod 2.5 | Compile-time safe providers, async state |
| Navigation | GoRouter 14 | Declarative routing, auth guards, deep links |
| Location | geolocator 13 | Cross-platform GPS with accuracy control |
| Secure Storage | flutter_secure_storage | Keychain (iOS) / EncryptedSharedPreferences (Android) |
| Config | flutter_dotenv | Environment-based API URL configuration |

### 3.3 Infrastructure

| Category | Technology |
|----------|-----------|
| Database | PostgreSQL 16 + PostGIS 3.4 |
| Cache | Redis 7 |
| Containerisation | Docker + Docker Compose |
| Admin Frontend | Next.js + TypeScript |
| Notifications | Twilio SMS API |
| Push Notifications | Firebase Cloud Messaging |
| Maps | Google Maps API |
| Healthcare Interop | FHIR R4 |

---

## 4. Backend Design

### 4.1 Application Structure

```
backend/
├── main.py                  # App factory, middleware, router registration
├── app/
│   ├── core/
│   │   ├── config.py        # Pydantic Settings with production guards
│   │   ├── database.py      # Async SQLAlchemy engine + session factory
│   │   ├── security.py      # JWT + bcrypt + role-based deps
│   │   ├── redis_client.py  # Async Redis: blocklist, cache, pub/sub
│   │   ├── logging.py       # Structured JSON logging + trace IDs
│   │   └── celery_app.py    # Celery broker configuration
│   ├── models/
│   │   └── models.py        # SQLAlchemy ORM models (10 tables)
│   ├── schemas/
│   │   ├── auth.py          # Register/Login/Token schemas
│   │   ├── rides.py         # RideRequest/RideResponse schemas
│   │   ├── patients.py      # Patient schemas
│   │   ├── drivers.py       # Driver schemas
│   │   ├── hospitals.py     # Hospital schemas
│   │   └── errors.py        # Error response schemas
│   ├── routers/
│   │   ├── auth.py          # Authentication endpoints
│   │   ├── rides.py         # Ride lifecycle endpoints
│   │   ├── patients.py      # Patient profile endpoints
│   │   ├── drivers.py       # Driver profile + location endpoints
│   │   ├── hospitals.py     # Hospital CRUD endpoints
│   │   ├── analytics.py     # Dashboard + forecast endpoints
│   │   └── ws.py            # WebSocket endpoints
│   └── services/
│       ├── ride_service.py           # Ride business logic
│       ├── emergency_dispatch.py     # AI triage + hospital match + driver dispatch
│       ├── hospital_matching.py      # Scoring engine
│       ├── hospital_service.py       # Hospital CRUD + caching
│       ├── patient_service.py        # Patient CRUD
│       ├── driver_service.py         # Driver CRUD + location
│       ├── notifications.py          # SMS + FHIR alerts
│       └── ws_manager.py             # Redis pub/sub location manager
```

### 4.2 Request Lifecycle

```
HTTP Request
    │
    ▼
Rate Limiter (slowapi)
    │
    ▼
CORS Middleware
    │
    ▼
Structured Logging Middleware (injects trace_id)
    │
    ▼
FastAPI Router
    │
    ▼
Dependency Injection
    ├── get_db() → AsyncSession
    └── get_current_user() → User
            │
            ├── Decode JWT
            ├── Check Redis blocklist
            └── Load User from DB
    │
    ▼
Route Handler → Service Layer → Database
    │
    ▼
Pydantic Response Model Serialisation
    │
    ▼
HTTP Response (with X-Trace-Id header)
```

### 4.3 Role-Based Access Control

SmartRide uses a **held-roles** model rather than a single active role:

- Every account has a `user_roles` join table listing all roles held
- JWT carries both `roles[]` (all held roles) and `active_role` (current portal)
- All permission checks use `held_roles` (set membership), not the active role
- This allows a patient/driver dual-account to access either portal's data regardless of which portal is currently selected

```
require_patient = require_role("patient")   # checks held_roles
require_driver  = require_role("driver")    # checks held_roles
require_admin   = require_role("admin")     # checks held_roles
```

---

## 5. Database Design

### 5.1 Entity Relationship Diagram

```
User ──────────── UserRoleLink (many)
  │
  ├──────────── Patient ──── Ride (many)
  │                            │
  └──────────── Driver         ├──── TriageEvent
                │              ├──── HospitalAlert
                └── Ride       └──── FamilyNotification
                (assigned)
                │
Hospital ───────┘
  │
  └──── HospitalAlert

AnalyticsHourly (standalone)
```

### 5.2 Table Definitions

#### User
| Column | Type | Notes |
|--------|------|-------|
| id | UUID (PK) | Auto-generated |
| phone | VARCHAR(20) UNIQUE | Login identifier |
| password_hash | TEXT | bcrypt hashed |
| role | ENUM(UserRole) | Active portal |
| is_active | BOOLEAN | Soft delete support |
| created_at, updated_at | TIMESTAMPTZ | UTC |

#### UserRoleLink
| Column | Type | Notes |
|--------|------|-------|
| id | UUID (PK) | |
| user_id | UUID (FK → User) | CASCADE DELETE |
| role | ENUM(UserRole) | UNIQUE(user_id, role) |

#### Patient
| Column | Type | Notes |
|--------|------|-------|
| id | UUID (PK) | |
| user_id | UUID (FK → User) | CASCADE DELETE |
| full_name | VARCHAR(100) | |
| date_of_birth | TIMESTAMPTZ | Optional |
| mobility_needs | TEXT | Wheelchair, stretcher, etc. |
| emergency_contact_name | VARCHAR(100) | |
| emergency_contact_phone | VARCHAR(20) | For SMS on dispatch |
| created_at | TIMESTAMPTZ | UTC |

#### Driver
| Column | Type | Notes |
|--------|------|-------|
| id | UUID (PK) | |
| user_id | UUID (FK → User) | CASCADE DELETE |
| full_name | VARCHAR(100) | |
| license_no | VARCHAR(50) UNIQUE | |
| vehicle_plate | VARCHAR(20) UNIQUE | |
| vehicle_type | VARCHAR(50) | Ambulance, car, etc. |
| is_verified | BOOLEAN | Admin verification required |
| status | ENUM(DriverStatus) | available / busy / offline |
| current_lat, current_lng | DOUBLE PRECISION | Last known GPS |
| last_seen_at | TIMESTAMPTZ | GPS update timestamp |
| created_at | TIMESTAMPTZ | |

**Indexes:** `(status)`, `(user_id)`

#### Hospital
| Column | Type | Notes |
|--------|------|-------|
| id | UUID (PK) | |
| name | VARCHAR(200) | |
| address, city | TEXT, VARCHAR(100) | |
| lat, lng | DOUBLE PRECISION | For distance scoring |
| phone | VARCHAR(20) | Optional |
| specialties | JSON | List of Specialty enums |
| ed_capacity | INTEGER | Total ED beds (default 50) |
| ed_current_load | INTEGER | Current patients (default 0) |
| fhir_endpoint | TEXT | FHIR R4 base URL if available |
| coordinator_phone | VARCHAR(20) | For pre-arrival SMS |
| is_active | BOOLEAN | Soft delete |
| created_at | TIMESTAMPTZ | |

#### Ride
| Column | Type | Notes |
|--------|------|-------|
| id | UUID (PK) | |
| patient_id | UUID (FK → Patient) | Not null |
| driver_id | UUID (FK → Driver) | Null until assigned |
| hospital_id | UUID (FK → Hospital) | Null until matched |
| ride_type | ENUM(RideType) | emergency / scheduled |
| status | ENUM(RideStatus) | State machine (see §4.4) |
| pickup_lat, pickup_lng | DOUBLE PRECISION | Required for dispatch |
| pickup_address | TEXT | Optional human-readable address |
| scheduled_for | TIMESTAMPTZ | Null for emergency rides |
| requested_at | TIMESTAMPTZ | Ride creation time |
| driver_assigned_at, pickup_at, arrived_at, completed_at, cancelled_at | TIMESTAMPTZ | Status transition timestamps |
| cancel_reason | TEXT | If cancelled |
| estimated_fare_pkr, final_fare_pkr | NUMERIC(10,2) | Fare tracking |
| created_at | TIMESTAMPTZ | |

**Indexes:** `(status)`, `(ride_type)`, `(requested_at)`, `(patient_id)`, `(driver_id)`

### 5.3 Ride Status State Machine

```
         [Patient books]
               │
               ▼
           PENDING ──────────────────────────► CANCELLED
               │                              (patient or admin)
               │ [Driver accepts / auto-dispatch]
               ▼
       DRIVER_ASSIGNED ─────────────────────► CANCELLED
               │
               │ [Driver updates]
               ▼
       DRIVER_EN_ROUTE ─────────────────────► CANCELLED
               │
               │ [Driver picks up patient]
               ▼
      PATIENT_PICKED_UP
               │
               │ [Arrived at hospital]
               ▼
    ARRIVED_AT_HOSPITAL
               │
               │ [Ride complete]
               ▼
           COMPLETED
```

### 5.4 Enumerations

**RideStatus:** `pending` → `driver_assigned` → `driver_en_route` → `patient_picked_up` → `arrived_at_hospital` → `completed` / `cancelled`

**RideType:** `emergency`, `scheduled`

**DriverStatus:** `available`, `busy`, `offline`

**UserRole:** `patient`, `driver`, `admin`

**Specialty (14 values):** `cardiology`, `neurology`, `orthopedics`, `pediatrics`, `obstetrics`, `psychiatry`, `oncology`, `nephrology`, `pulmonology`, `gastroenterology`, `ophthalmology`, `dermatology`, `general_surgery`, `general_emergency`

**SeverityLevel (ESI scale):** `1` (immediate) → `5` (non-urgent)

---

## 6. AI Triage Service

### 6.1 Overview

A standalone FastAPI microservice (`http://triage:8001`) that accepts symptom text and returns a structured triage result.

### 6.2 Triage Pipeline

```
Symptom Text (patient input)
        │
        ▼
┌───────────────────────────┐
│  Rule-Based Pre-screening │  ← Detects critical keywords
│  (chest pain, stroke, etc)│    Forces severity=1 override
└────────────┬──────────────┘
             │
             ▼
┌───────────────────────────┐
│    ML Classification      │  ← Predicts specialty + confidence
│    Model (14 classes)     │
└────────────┬──────────────┘
             │
             ▼
┌───────────────────────────┐
│   ESI Severity Scoring    │  ← Assigns 1–5 severity level
└────────────┬──────────────┘
             │
             ▼
Response: {
  specialty: "cardiology",
  confidence: 0.91,
  severity: 1,
  rule_override: true,
  model_version: "1.0.0"
}
```

### 6.3 Triage Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `specialty` | Specialty enum | Required hospital specialty |
| `confidence` | float (0–1) | Model confidence score |
| `severity` | int (1–5) | ESI triage level (1 = most urgent) |
| `rule_override` | bool | True if rule-based override applied |
| `model_version` | string | For audit trail in TriageEvent |

### 6.4 Fallback Behaviour

If the triage service is unreachable:
- `detect_severity_override()` scans symptom text for critical keywords
- Falls back to `general_emergency` specialty
- Dispatch continues without triage — patient safety prioritised over data completeness

---

## 7. Mobile Application

### 7.1 Architecture

The Flutter app follows a **feature-first architecture** with Riverpod for state management:

```
apps/patient_app/lib/
├── main.dart                    # Entry point, Firebase init
├── core/
│   ├── router.dart              # GoRouter config + auth guards
│   └── providers.dart           # Auth, roles, GPS stream providers
└── features/
    ├── auth/                    # Login, signup, role management
    ├── rides/                   # Booking, tracking, history
    ├── driver/                  # Driver dashboard + active ride
    ├── profile/                 # Patient + driver profiles
    └── support/                 # Help, contact screens
```

### 7.2 Dual-Portal Design

A single APK serves both patient and driver portals, toggled via `activeRoleProvider`:

| Portal | Theme | Entry Route | Key Screens |
|--------|-------|-------------|-------------|
| Patient | Blue | `/` | Home → Symptoms → Dispatching → Tracking |
| Driver | Teal | `/driver` | Dashboard → Active Ride → Profile |

Route guards in GoRouter redirect unauthenticated users to `/welcome` and route authenticated users to the correct portal based on `activeRoleProvider`.

### 7.3 Navigation Map

```
/welcome ──┬─► /login ──────────────────────────────► /  (patient home)
           └─► /signup                                  │
                                                        ├─► /symptoms
Patient                                                 ├─► /dispatching/:id
portal                                                  ├─► /tracking/:id
                                                        ├─► /book-ride
                                                        ├─► /rides
                                                        ├─► /ride/:id
                                                        ├─► /profile
                                                        └─► /help

Driver                                          /driver ─► /driver/ride/:id
portal                                                  └─► /driver/profile
```

### 7.4 State Management

| Provider | Type | Purpose |
|----------|------|---------|
| `authProvider` | `AsyncNotifierProvider` | JWT token; sign in/out/register |
| `rolesProvider` | `StateProvider<List<String>>` | All held roles |
| `activeRoleProvider` | `StateProvider<String>` | Current portal (patient/driver) |
| `ridesProvider` | `AsyncNotifierProvider` | Ride list with refresh |
| `activeRideProvider` | `Provider` | Derived: first active ride from `ridesProvider` |
| `gpsStreamProvider` | `StateNotifierProvider<bool>` | Driver GPS WebSocket stream |

### 7.5 GPS Streaming (Driver)

```
Driver goes online
      │
      ▼
gpsStreamProvider.startStreaming(rideId)
      │
      ├─► Geolocator.getPositionStream(
      │     accuracy: high,
      │     distanceFilter: 10m
      │   )
      │
      └─► WebSocket connect to /ws/driver/{rideId}
               │
               ▼
         Every 10m or 5s (rate-limited):
         Send {"lat": <>, "lng": <>}
               │
               ▼
         Backend publishes to Redis pub/sub
               │
               ▼
         Patient's /ws/ride/{rideId} receives update
               │
               ▼
         LiveTrackingScreen updates map marker
```

### 7.6 Shared Package (`smartride_core`)

All models, API client, theme, and validators are extracted into a shared Dart package:

```
packages/smartride_core/lib/
├── src/
│   ├── api/
│   │   ├── api_client.dart      # HTTP client with auth injection
│   │   ├── endpoints.dart       # Route constants
│   │   ├── api_error.dart       # Typed exception hierarchy
│   │   └── ws_client.dart       # WebSocket wrapper
│   ├── models/
│   │   ├── user.dart            # Auth models
│   │   ├── ride.dart            # Ride models + enums
│   │   ├── patient.dart
│   │   ├── driver.dart
│   │   ├── hospital.dart
│   │   └── triage.dart
│   ├── storage/
│   │   └── secure_storage.dart  # Token + role persistence
│   ├── theme/
│   │   ├── app_theme.dart       # Patient (blue) + Driver (teal) themes
│   │   └── design_tokens.dart   # Spacing, colours, typography
│   ├── validators/
│   │   └── validators.dart      # Phone, password validation
│   └── widgets/
│       ├── primary_button.dart
│       ├── loading_state.dart
│       ├── error_state.dart
│       └── empty_state.dart
└── smartride_core.dart          # Barrel export
```

---

## 8. Admin Dashboard

A **Next.js + TypeScript** web application (port 3000) for system operators:

### 8.1 Features

| Module | Capability |
|--------|-----------|
| Driver Management | List, verify/unverify drivers, view location history |
| Hospital Management | Add/edit hospitals, update ED capacity and load |
| Ride Management | View all rides, filter by status/type, drill into details |
| Analytics Dashboard | Live metrics, 7-day ride history, 6-hour demand forecast |
| User Management | View registered patients and drivers |

### 8.2 Analytics Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /analytics/summary` | Live: total rides, active rides, available drivers |
| `GET /analytics/history?city=ISB&days=7` | Hourly ride counts for charts |
| `GET /analytics/forecast?city=ISB&hours_ahead=6` | 7-day rolling average demand forecast |
| `POST /analytics/snapshot` | Manually trigger hourly data capture |

---

## 9. Real-Time Communication

### 9.1 WebSocket Architecture

```
Driver App                Backend                  Patient App
    │                        │                          │
    │── WS /ws/driver/{id} ──►│                          │
    │   {token: "..."}        │                          │
    │◄── {ack: true} ─────────│                          │
    │                        │◄── WS /ws/ride/{id} ─────│
    │                        │    {token: "..."}         │
    │── {lat: x, lng: y} ───►│                          │
    │                        │── Redis PUBLISH ─────────►│
    │                        │   location:{id}           │
    │                        │   {lat, lng}              │
    │                        │◄── Redis SUBSCRIBE ───────│
    │                        │── {lat: x, lng: y} ──────►│
    │                        │                    (map updates)
```

### 9.2 WebSocket Authentication

All WebSocket connections require JWT authentication as the **first message**:

```json
{"token": "<jwt_access_token>"}
```

The server validates the token, checks the Redis blocklist, and closes the connection with code 4001 if invalid.

### 9.3 Redis Pub/Sub Channel Naming

Channel: `location:{ride_id}`

Each GPS update is published as:
```json
{"lat": 33.6844, "lng": 73.0479, "timestamp": "2026-06-06T15:00:00Z"}
```

---

## 10. Security Design

### 10.1 Authentication

| Mechanism | Implementation |
|-----------|---------------|
| Password hashing | bcrypt via passlib (12 rounds) |
| Token format | JWT (HS256, configurable algorithm) |
| Token payload | `sub` (user_id), `roles[]`, `active_role`, `exp`, `iat`, `jti` |
| Token lifetime | 60 minutes (configurable) |
| Token revocation | Redis blocklist keyed by `jti`, TTL = remaining token lifetime |
| Refresh flow | Exchange valid token for new one; old token immediately blocked |

### 10.2 Authorisation

- **RBAC via held_roles**: permission checks use set membership against all roles held, not the active portal
- **Ownership checks**: patients can only access their own rides; drivers only their assigned rides; admins see all
- **Driver verification**: `is_verified=True` required for ride acceptance and location updates

### 10.3 Production Guards

The app refuses to start (`Settings` model validator) if:
- `SECRET_KEY` is the placeholder default (`change_me_to_a_32_char_random_string_here`)
- `ALLOWED_ORIGINS` contains `"*"` when `DEBUG=False`

### 10.4 Rate Limiting

| Endpoint | Limit |
|----------|-------|
| `POST /auth/register` | 5 requests / minute |
| `POST /auth/login` | 10 requests / minute |
| All other endpoints | 200 requests / minute (default) |

### 10.5 Input Validation

- All request bodies validated by Pydantic v2 schemas with field-level constraints
- `symptom_text`: min 1 char, max 2,000 chars
- Ride coordinates: required floats (no defaults — prevents silent wrong-location dispatch)
- Enum fields validated at schema boundary (invalid values return 422)

### 10.6 Secrets Management

| Secret | Storage |
|--------|---------|
| JWT access tokens | Flutter secure storage (Keychain / EncryptedSharedPreferences) |
| API keys (Twilio, Google Maps) | Environment variables / `.env` file (never in source) |
| Database credentials | Environment variables |
| Driver GPS stream auth | WebSocket first-message JWT (not URL params) |

---

## 11. API Reference

### 11.1 Base URL

```
https://api.smartride.pk/api/v1/
```

### 11.2 Authentication

All endpoints except registration, login, and hospital listing require:

```
Authorization: Bearer <access_token>
```

### 11.3 Endpoint Summary

#### Auth (`/auth`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | None | Create account (patient/driver/both) |
| POST | `/auth/login` | None | Authenticate and get token |
| POST | `/auth/logout` | Bearer | Revoke current token |
| POST | `/auth/refresh` | Bearer | Exchange token for fresh one |
| GET | `/auth/me` | Bearer | Current user profile + roles |
| POST | `/auth/add-role` | Bearer | Add patient or driver role |
| POST | `/auth/switch-role` | Bearer | Change active portal |

#### Patients (`/patients`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/patients/me` | Patient | Get my profile |
| PATCH | `/patients/me` | Patient | Update my profile |
| GET | `/patients` | Admin | List all patients |

#### Drivers (`/drivers`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/drivers/me` | Driver | Get my profile |
| PATCH | `/drivers/me` | Driver | Update my profile |
| PATCH | `/drivers/status` | Driver | Set availability status |
| POST | `/drivers/location` | Driver | Post GPS coordinates |
| GET | `/drivers` | Admin | List all drivers |
| PATCH | `/drivers/{id}/verify` | Admin | Verify / unverify driver |

#### Rides (`/rides`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/rides/emergency` | Patient | Request emergency ride (triggers AI dispatch) |
| POST | `/rides/scheduled` | Patient | Book future ride |
| GET | `/rides/mine` | Patient/Driver | My rides (paginated) |
| GET | `/rides/pending` | Driver (verified) | Available rides near me |
| POST | `/rides/{id}/accept` | Driver (verified) | Accept a pending ride |
| PATCH | `/rides/{id}/status` | Patient/Driver | Update ride status |
| GET | `/rides/{id}` | Patient/Driver/Admin | Get ride details |
| GET | `/rides/{id}/detail` | Any | Full ride with triage/hospital info |
| GET | `/rides` | Admin | All rides (filtered, paginated) |

#### Hospitals (`/hospitals`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/hospitals` | None | List active hospitals (cached 5min) |
| GET | `/hospitals/{id}` | None | Get hospital details |
| POST | `/hospitals` | Admin | Create hospital |
| PATCH | `/hospitals/{id}` | Admin | Update hospital |

#### Analytics (`/analytics`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/analytics/summary` | Admin | Live dashboard metrics |
| POST | `/analytics/snapshot` | Admin | Record hourly snapshot |
| GET | `/analytics/history` | Admin | Historical ride counts |
| GET | `/analytics/forecast` | Admin | Demand forecast (7-day rolling avg) |

#### WebSockets (`/ws`)

| Path | Auth | Description |
|------|------|-------------|
| `/ws/driver/{ride_id}` | JWT first-message | Driver GPS upload |
| `/ws/ride/{ride_id}` | JWT first-message | Patient live tracking |

### 11.4 Standard Response Formats

**Success:**
```json
{
  "id": "uuid",
  "status": "pending",
  ...
}
```

**Paginated list:**
```json
{
  "items": [...],
  "total": 42
}
```

**Error:**
```json
{
  "detail": "Human-readable error message"
}
```

---

## 12. Deployment Architecture

### 12.1 Docker Compose Services

```yaml
Services:
  postgres   ← PostgreSQL 16 + PostGIS (port 5432)
  redis      ← Redis 7 (port 6379)
  backend    ← FastAPI (port 8000)
  triage     ← AI triage FastAPI (port 8001)
  celery_worker ← Celery background tasks (no external port)
  admin_dashboard ← Next.js (port 3000)
```

### 12.2 Environment Variables (Required for Production)

```bash
# Security (REQUIRED — app refuses to start without these)
SECRET_KEY=<64-char random hex string>
ALLOWED_ORIGINS=["https://admin.smartride.pk"]

# Database
DATABASE_URL=postgresql+asyncpg://user:pass@host:5432/smartride

# Redis
REDIS_URL=redis://host:6379/0

# AI Service
TRIAGE_SERVICE_URL=http://triage:8001

# Twilio (SMS notifications)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_FROM_NUMBER=+1234567890

# Google Maps (geocoding)
GOOGLE_MAPS_API_KEY=AIza...

# Firebase (push notifications)
FIREBASE_PROJECT_ID=smartride-xxxxx

# App
DEBUG=false
LOG_LEVEL=INFO
```

### 12.3 Health Checks

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Liveness — always returns 200 if app is running |
| `GET /ready` | Readiness — checks PostgreSQL + Redis connectivity |
| `GET /metrics` | Prometheus-compatible metrics |

---

## 13. Emergency Dispatch Pipeline

This is the core differentiating feature of SmartRide. When a patient submits an emergency ride request, the following pipeline runs as a **FastAPI background task** with a target completion time of **under 60 seconds**:

```
Patient submits EmergencyRideRequest
{pickup_lat, pickup_lng, pickup_address, symptom_text}
        │
        ▼
Step 1: Create Ride record (status=PENDING)
        │
        │  [Background task starts]
        ▼
Step 2: Parallel execution:
        ├─► Call AI Triage Service (HTTP, timeout=10s)
        │       └─► Returns: specialty, confidence, severity
        │           (fallback: rule-based keyword detection)
        │
        └─► Load active hospitals from database
        │
        ▼
Step 3: Hospital Matching
        Inputs: patient location, required specialty, hospital list
        Scoring (per hospital):
          ├─ Distance score:    40% weight (Haversine km)
          ├─ ED wait score:     30% weight (current_load / capacity)
          ├─ Specialty score:   20% weight (exact match vs fallback)
          └─ Outcome score:     10% weight (historical performance, default 0.5)
        Hard filters: within 30km, ED not full, specialty available
        Returns: top 3 ranked hospitals
        │
        ▼
Step 4: Find Nearest Available Driver
        Query: drivers WHERE status=available AND is_verified=true
        Sort by Haversine distance from patient pickup
        Returns: nearest driver (or None if unavailable)
        │
        ▼
Step 5: Atomic Ride Assignment
        UPDATE rides
        SET driver_id=?, hospital_id=?, status=driver_assigned,
            driver_assigned_at=now()
        WHERE id=? AND driver_id IS NULL   ← prevents race conditions
        Returns 409 if another request already assigned a driver
        │
        ▼
Step 6: Parallel notifications:
        ├─► Send family SMS (Twilio)
        │       "Your [name] is being transported to [hospital]"
        │
        └─► Send hospital pre-alert
                If FHIR endpoint available: POST FHIR Encounter resource
                Else: SMS to coordinator_phone
        │
        ▼
Step 7: Log TriageEvent (audit trail)
        {ride_id, specialty, confidence, severity, rule_override, model_version}
        │
        ▼
Pipeline complete — patient app polls for status update
Driver app shows new ride in pending list
```

---

## 14. Data Flow Diagrams

### 14.1 User Registration

```
Mobile App          Backend                   Database
    │                  │                          │
    │─ POST /register ─►│                          │
    │  {phone, pass,    │                          │
    │   roles, name}    │                          │
    │                   │── SELECT user by phone ─►│
    │                   │◄── None (not exists) ────│
    │                   │── INSERT User ───────────►│
    │                   │── INSERT UserRoleLink ───►│
    │                   │── INSERT Patient/Driver ─►│
    │                   │── COMMIT ────────────────►│
    │◄─ 201 TokenResponse│                          │
    │   {token, roles}  │                          │
    │                   │                          │
    │ [Save to secure storage]                      │
```

### 14.2 Emergency Ride — Full Flow

```
Patient App    Backend    Triage    Database    Driver App    Patient Family
     │            │          │          │           │              │
     │─ POST ────►│          │          │           │              │
     │  /emergency│          │          │           │              │
     │            │─ INSERT ─────────────►│          │              │
     │            │  Ride (PENDING)    │           │              │
     │◄─ 201 ─────│          │          │           │              │
     │  RideResp  │          │          │           │              │
     │            │          │          │           │              │
     │  [Background task]    │          │           │              │
     │            │─ POST ──►│          │           │              │
     │            │  /triage │          │           │              │
     │            │◄─ result─│          │           │              │
     │            │          │          │           │              │
     │            │─ Match hospitals ───►│          │              │
     │            │◄─ ranked list ──────│           │              │
     │            │          │          │           │              │
     │            │─ Find nearest driver ──────────►│              │
     │            │          │          │           │              │
     │            │─ UPDATE Ride ───────►│          │              │
     │            │  (DRIVER_ASSIGNED)  │           │              │
     │            │          │          │           │              │
     │            │──────────────────────────────── SMS ──────────►│
     │            │─ FHIR/SMS to hospital coordinator              │
     │            │          │          │           │              │
     │  [Polls or WebSocket] │          │           │              │
     │◄─ status: driver_assigned        │           │              │
```

### 14.3 Live Tracking

```
Driver App          Backend (WS)         Redis          Patient App
     │                   │                  │                 │
     │── WS connect ────►│                  │                 │
     │   /ws/driver/{id} │                  │                 │
     │   {token: "..."}  │                  │                 │
     │                   │── SUBSCRIBE ────►│                 │
     │                   │   location:{id}  │                 │
     │                   │                  │◄── WS connect ──│
     │                   │                  │    /ws/ride/{id}│
     │── {lat,lng} ──────►│                  │                 │
     │                   │── PUBLISH ──────►│                 │
     │                   │   location:{id}  │                 │
     │                   │   {lat,lng}      │                 │
     │                   │                  │─ message ──────►│
     │                   │                  │  {lat,lng}      │
     │                   │                  │         [map updates]
```

---

*Document generated from source code analysis — June 2026.*  
*SmartRide NEMT, Final Year Project, FAST-NUCES Islamabad.*
