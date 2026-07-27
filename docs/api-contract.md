# SmartRide NEMT — API Contract

Base URL: `http://localhost:8000/api/v1`

All authenticated endpoints require: `Authorization: Bearer <jwt_token>`

---

## Auth

### `POST /auth/register`
**Auth:** public

**Request body:**
```json
{
  "phone": "+923001234567",
  "password": "securepass",
  "role": "patient | driver | admin",
  "full_name": "Ali Khan",

  // Driver-only fields (required when role=driver):
  "license_no": "LHR-123456",
  "vehicle_plate": "ABC-1234",
  "vehicle_type": "sedan"
}
```

**Response `201`:**
```json
{
  "access_token": "<jwt>",
  "token_type": "bearer",
  "role": "patient",
  "user_id": "<uuid>"
}
```

**Errors:** `400` duplicate phone | `400` driver missing vehicle fields

---

### `POST /auth/login`
**Auth:** public

**Request body:**
```json
{ "phone": "+923001234567", "password": "securepass" }
```

**Response `200`:**
```json
{
  "access_token": "<jwt>",
  "token_type": "bearer",
  "role": "patient",
  "user_id": "<uuid>"
}
```

**Errors:** `401` wrong credentials | `403` account inactive

---

## Patients

### `GET /patients/me`
**Auth:** patient

**Response `200`:**
```json
{
  "id": "<uuid>",
  "phone": "+923001234567",
  "full_name": "Ali Khan",
  "date_of_birth": "1990-05-15",
  "mobility_needs": "wheelchair",
  "emergency_contact_name": "Sara Khan",
  "emergency_contact_phone": "+923009876543",
  "created_at": "2026-01-01T00:00:00Z"
}
```

---

### `PATCH /patients/me`
**Auth:** patient

**Request body (all fields optional):**
```json
{
  "full_name": "Ali Khan",
  "date_of_birth": "1990-05-15",
  "mobility_needs": "stretcher",
  "emergency_contact_name": "Sara Khan",
  "emergency_contact_phone": "+923009876543"
}
```

**Response `200`:** updated patient object

---

## Drivers

### `GET /drivers/me`
**Auth:** driver

**Response `200`:**
```json
{
  "id": "<uuid>",
  "full_name": "Usman Ahmed",
  "license_no": "ISB-789",
  "vehicle_plate": "LHR-5678",
  "vehicle_type": "sedan",
  "is_verified": true,
  "status": "available",
  "current_lat": 33.7005,
  "current_lng": 73.0679,
  "last_seen_at": "2026-01-01T12:00:00Z"
}
```

---

### `PATCH /drivers/me`
**Auth:** driver

**Request body (all optional):** `full_name`, `vehicle_type`

**Response `200`:** updated driver object

---

### `PATCH /drivers/status`
**Auth:** driver

**Request body:**
```json
{ "status": "available | busy | offline" }
```

**Response `200`:** `{ "status": "available" }`

---

### `POST /drivers/location`
**Auth:** driver

**Request body:**
```json
{ "lat": 33.7005, "lng": 73.0679 }
```

**Response `200`:** `{ "updated": true }`

---

### `GET /drivers`
**Auth:** admin

**Query params:** `status`, `is_verified`, `page`, `page_size`

**Response `200`:**
```json
{
  "items": [ /* driver objects */ ],
  "total": 42,
  "page": 1
}
```

---

### `PATCH /drivers/{id}/verify`
**Auth:** admin

**Response `200`:** `{ "id": "<uuid>", "is_verified": true }`

**Errors:** `404` driver not found

---

## Hospitals

### `GET /hospitals`
**Auth:** public

**Query params:** `city`, `specialty`, `page`, `page_size`

**Response `200`:**
```json
{
  "items": [
    {
      "id": "<uuid>",
      "name": "PIMS",
      "address": "G-8/3, Islamabad",
      "city": "Islamabad",
      "lat": 33.7005,
      "lng": 73.0679,
      "specialties": ["cardiology", "neurology"],
      "ed_capacity": 120,
      "ed_current_load": 45,
      "is_active": true
    }
  ],
  "total": 5
}
```

---

### `GET /hospitals/admin`
**Auth:** admin

Same listing as `GET /hospitals`, but each item also carries the internal
`fhir_endpoint` and `coordinator_phone` fields. Used by the admin dashboard to
prefill the hospital edit form.

**Errors:** `401` unauthenticated, `403` not an admin

---

### `GET /hospitals/{id}`
**Auth:** public

**Response `200`:** single hospital object. `fhir_endpoint` and
`coordinator_phone` are **not** included — they are internal fields exposed only
on admin routes (`GET /hospitals/admin`, `POST /hospitals`, `PATCH /hospitals/{id}`).

**Errors:** `404` not found

---

### `POST /hospitals`
**Auth:** admin

**Request body:**
```json
{
  "name": "New Hospital",
  "address": "F-7, Islamabad",
  "city": "Islamabad",
  "lat": 33.7215,
  "lng": 73.0826,
  "phone": "+9251xxxxxxx",
  "specialties": ["cardiology", "general_emergency"],
  "ed_capacity": 80,
  "fhir_endpoint": "https://hospital.example.com/fhir",
  "coordinator_phone": "+9251xxxxxxx"
}
```

**Response `201`:** created hospital object

---

### `PATCH /hospitals/{id}`
**Auth:** admin

**Request body (all optional):** any hospital field, including `ed_current_load`

**Response `200`:** updated hospital object

---

## Rides

### `POST /rides/emergency`
**Auth:** patient

**Request body:**
```json
{
  "pickup_lat": 33.7005,
  "pickup_lng": 73.0679,
  "symptom_text": "Severe chest pain, can't breathe"
}
```

**Response `202`:**
```json
{
  "ride_id": "<uuid>",
  "status": "pending",
  "message": "Emergency dispatched. Poll GET /rides/{id} for driver assignment."
}
```

Dispatch pipeline runs in background. Target: driver assigned within 60 seconds.

---

### `POST /rides/book`
**Auth:** patient

**Request body:**
```json
{
  "ride_type": "scheduled",
  "pickup_lat": 33.7005,
  "pickup_lng": 73.0679,
  "pickup_address": "House 5, Street 3, F-8/2",
  "scheduled_for": "2026-06-01T09:00:00Z"
}
```

**Response `201`:**
```json
{ "ride_id": "<uuid>", "status": "pending", "scheduled_for": "2026-06-01T09:00:00Z" }
```

---

### `GET /rides/{id}`
**Auth:** patient (own ride) | driver (assigned ride) | admin (any)

**Response `200`:**
```json
{
  "id": "<uuid>",
  "ride_type": "emergency",
  "status": "driver_assigned",
  "pickup_lat": 33.7005,
  "pickup_lng": 73.0679,
  "driver": {
    "id": "<uuid>",
    "full_name": "Usman Ahmed",
    "vehicle_plate": "LHR-5678",
    "current_lat": 33.695,
    "current_lng": 73.060
  },
  "hospital": {
    "id": "<uuid>",
    "name": "PIMS",
    "lat": 33.7005,
    "lng": 73.0679
  },
  "triage": {
    "specialty": "cardiology",
    "severity": "5",
    "confidence": 0.78
  },
  "requested_at": "2026-01-01T12:00:00Z",
  "driver_assigned_at": "2026-01-01T12:00:45Z"
}
```

**Errors:** `403` not your ride | `404` not found

---

### `PATCH /rides/{id}/status`
**Auth:** driver (assigned to this ride)

**Request body:**
```json
{ "status": "driver_en_route | patient_picked_up | arrived_at_hospital | completed" }
```

**Response `200`:** `{ "id": "<uuid>", "status": "driver_en_route" }`

**Errors:** `400` invalid status transition | `403` not assigned driver

---

## Analytics

### `GET /analytics/overview`
**Auth:** admin

**Query params:** `city`, `start_date`, `end_date`

**Response `200`:**
```json
{
  "total_rides": 1250,
  "emergency_rides": 340,
  "scheduled_rides": 910,
  "avg_eta_seconds": 38.4,
  "missed_appointments": 22,
  "driver_utilisation_pct": 67.3,
  "by_specialty": {
    "cardiology": 120,
    "neurology": 45,
    "general_emergency": 175
  },
  "by_status": {
    "completed": 1180,
    "cancelled": 48,
    "pending": 22
  }
}
```

---

### `GET /analytics/export.csv`
**Auth:** admin

**Query params:** `start_date`, `end_date`, `city`

**Response `200`:** `Content-Type: text/csv`

CSV columns: `ride_id, ride_type, status, patient_id, driver_id, hospital_name, specialty, severity, requested_at, driver_assigned_at, completed_at, pickup_lat, pickup_lng, city`

---

## WebSocket

### `WS /ws/driver/{driver_id}/location`
**Auth:** driver (JWT in query param `?token=<jwt>`)

Driver streams location every ~5 seconds:
```json
{ "lat": 33.7005, "lng": 73.0679, "timestamp": "2026-01-01T12:00:00Z" }
```

Server acknowledges: `{ "ok": true }`

---

### `WS /ws/ride/{ride_id}/track`
**Auth:** patient or admin (JWT in query param `?token=<jwt>`)

Server pushes driver location updates in real time:
```json
{
  "driver_id": "<uuid>",
  "lat": 33.6980,
  "lng": 73.0650,
  "timestamp": "2026-01-01T12:00:05Z"
}
```

Connection closes automatically when ride status becomes `completed` or `cancelled`.

---

## Error format

All errors follow:
```json
{
  "detail": "Human-readable error message"
}
```

## Status codes used

| Code | Meaning |
|---|---|
| 200 | OK |
| 201 | Created |
| 202 | Accepted (async dispatch) |
| 400 | Bad request / validation error |
| 401 | Unauthenticated |
| 403 | Forbidden (wrong role or not owner) |
| 404 | Not found |
| 422 | Unprocessable entity (Pydantic validation) |
| 500 | Internal server error |
