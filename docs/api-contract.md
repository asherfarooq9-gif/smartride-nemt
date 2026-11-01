# SmartRide NEMT — API Contract

Base URL: `http://localhost:18020/api/v1` (Docker compose default; WebSockets are under `/ws`, not `/api/v1`)

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
  "roles": ["patient", "driver"],
  "active_role": "patient",
  "full_name": "Ali Khan",

  // `roles` is one or more of patient | driver. The legacy single `role`
  // field is still accepted. `active_role` defaults to the first role.
  // Driver-only fields (required when "driver" is among the roles):
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
  "roles": ["patient"],
  "active_role": "patient",
  "role": "patient",
  "user_id": "<uuid>"
}
```

**Errors:** `400` duplicate phone | `403` admin accounts cannot be self-registered | `422` driver missing vehicle fields or bad `active_role`

`role` is the legacy copy of `active_role`. Rate limit 5/min.

---

### `POST /auth/login`
**Auth:** public

**Request body:**
```json
{ "phone": "+923001234567", "password": "securepass", "active_role": "patient" }
```

**Response `200`:**
```json
{
  "access_token": "<jwt>",
  "token_type": "bearer",
  "roles": ["patient"],
  "active_role": "patient",
  "role": "patient",
  "user_id": "<uuid>"
}
```

`active_role` is optional. **Errors:** `401` wrong credentials | `403` account disabled or role not held | `429` too many failed attempts. Rate limit 10/min.

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
  "phone": "+923001234567",
  "full_name": "Usman Ahmed",
  "license_no": "ISB-789",
  "vehicle_plate": "LHR-5678",
  "vehicle_type": "sedan",
  "is_verified": true,
  "status": "available",
  "wallet_balance_pkr": 0,
  "current_lat": 33.7005,
  "current_lng": 73.0679,
  "last_seen_at": "2026-01-01T12:00:00Z",
  "created_at": "2026-01-01T00:00:00Z"
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

**Response `200`:** the driver object (as `GET /drivers/me`). Rate limit 30/min.

---

### `POST /drivers/location`
**Auth:** driver

**Request body:**
```json
{ "lat": 33.7005, "lng": 73.0679 }
```

**Response `200`:** the driver object. Rate limit 60/min.

---

### `GET /drivers/demand-forecast`
**Auth:** driver

Busy hours ahead: the average number of ride requests per hour, from the same hour of the day over the last 28 days. Hours are counted in Pakistan time (UTC+5). Counts only; no patient data.

**Query params:** `hours_ahead` (1-24, default 6)

**Response `200`:**
```json
{
  "generated_at": "2026-10-30T10:00:00Z",
  "method": "hourly_average_28d",
  "has_data": true,
  "forecast": [
    { "hour": "2026-10-30T11:00:00Z", "predicted_rides": 1.3, "level": "high" }
  ]
}
```

`hour` is the start of the hour in UTC. `level` is `low`, `medium` or `high`, relative to the busiest hour of the day. When there are no past rides, `has_data` is `false` and every hour is `low` with 0 predicted rides.

---

### `GET /drivers`
**Auth:** admin

**Query params:** `status`, `is_verified`, `search`, `page`, `page_size`

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

**Request body (optional):** `{ "is_verified": true }` (defaults to `true`; send `false` to revoke)

**Response `200`:** the driver object

**Errors:** `404` driver not found

---

## Hospitals

### `GET /hospitals`
**Auth:** public

**Query params:** `active_only` (default `true`; only admins can list inactive hospitals), `page` (default 1), `page_size` (1-200, default 50)

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

### `GET /hospitals/{id}`
**Auth:** public

**Response `200`:** single hospital object. `fhir_endpoint` and `coordinator_phone` are `null` unless the caller is an admin.

**Errors:** `404` not found (inactive hospitals are hidden from non-admins)

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
  "pickup_address": "optional, max length enforced",
  "symptom_text": "Severe chest pain, can't breathe"
}
```

**Response `201`:** the ride object (`id`, `status: "pending"`, `ride_type: "emergency"`, ...; same shape as `GET /rides/{id}`).
**Response `200`:** the patient already has a live emergency ride, or the same `Idempotency-Key` was replayed. That ride is returned and no new dispatch starts.

Dispatch runs in the background; poll `GET /rides/{id}` or open the ride WebSocket. Rate limit 5/min.

---

### `POST /rides/scheduled`
**Auth:** patient

**Request body:**
```json
{
  "pickup_lat": 33.7005,
  "pickup_lng": 73.0679,
  "pickup_address": "House 5, Street 3, F-8/2",
  "scheduled_for": "2026-06-01T09:00:00Z",
  "hospital_id": "<uuid, optional>"
}
```

`scheduled_for` must be in the future. `hospital_id` is the destination the patient
chose; an unknown or inactive hospital returns `404`.

**Response `201`:** the ride (`id`, `status: "pending"`, `ride_type: "scheduled"`,
`scheduled_for`, `hospital_id`, ...). `200` on an `Idempotency-Key` replay. Rate limit 10/min.

---

### `GET /rides/{id}`
**Auth:** patient (own ride) | driver (assigned ride) | admin (any)

**Response `200`:** a flat ride object. Driver, hospital and triage details are in `GET /rides/{id}/detail`.
```json
{
  "id": "<uuid>",
  "patient_id": "<uuid>",
  "driver_id": "<uuid | null>",
  "hospital_id": "<uuid | null>",
  "ride_type": "emergency",
  "status": "driver_assigned",
  "pickup_lat": 33.7005,
  "pickup_lng": 73.0679,
  "pickup_address": null,
  "scheduled_for": null,
  "requested_at": "2026-01-01T12:00:00Z",
  "driver_assigned_at": "2026-01-01T12:00:45Z",
  "pickup_at": null,
  "arrived_at": null,
  "completed_at": null,
  "cancelled_at": null,
  "cancel_reason": null,
  "estimated_fare_pkr": null,
  "final_fare_pkr": null,
  "patient_rating": null,
  "rating_comment": null,
  "hospital_name": null
}
```

**Errors:** `403` not your ride | `404` not found

---

### `PATCH /rides/{id}/status`
**Auth:** the assigned driver (verified), the owning patient, or an admin. The caller must hold the role that owns the ride.

**Request body:**
```json
{ "status": "driver_en_route | patient_picked_up | arrived_at_hospital | completed | cancelled", "cancel_reason": "optional" }
```

Drivers move the ride forward and may cancel before pickup. Patients and admins can only set `cancelled`.

**Response `200`:** the ride object.

**Errors:** `400` invalid transition | `403` not your ride, or driver not verified | `409` driver cancelling after pickup

---

## Analytics

All admin only. Response bodies are not yet schema-typed; see `backend/app/routers/analytics.py`.

| Endpoint | Purpose |
|---|---|
| `GET /analytics/summary` | Dashboard counters (cached `SUMMARY_CACHE_SECONDS`, default 15 s) |
| `POST /analytics/snapshot` | Write the current hourly snapshot (`201`) |
| `GET /analytics/forecast` | Demand forecast for the dashboard charts |
| `GET /analytics/history` | Stored hourly snapshots |

CSV export is `GET /rides/export.csv` (admin), not an analytics route.

---

## Endpoints added since the first draft

These exist in code and were missing from this contract. Request and response
models live in `backend/app/schemas/`.

**Auth** (rate limits per client: register 5/min, login 10/min, add-role 5/min, switch-role and refresh 20/min)

| Endpoint | Auth | Purpose |
|---|---|---|
| `POST /auth/add-role` | any user | Add the patient or driver role to an account (admin cannot be added) |
| `POST /auth/switch-role` | any user | Change the active portal; returns a new token |
| `GET /auth/me` | any user | Profiles, held roles, `driver_verified` |
| `POST /auth/fcm-token` | any user | Register the device push token (`204`) |
| `POST /auth/logout` | any user | Revoke this token (`204`) |
| `POST /auth/logout-all` | any user | Bump `token_version`: every token, HTTP and WebSocket, stops working (`204`) |
| `POST /auth/refresh` | the token itself | New token; the session is capped at `SESSION_MAX_DAYS` |

**Patients:** `GET /patients` (admin list).

**Drivers**

| Endpoint | Auth | Purpose |
|---|---|---|
| `GET /drivers/earnings` | driver | Earnings summary and recent rides |
| `GET /drivers/wallet` | driver | Balance, plan, ledger entries (read only) |
| `POST /drivers/{driver_id}/wallet/topup` | admin | Credit a wallet. `Idempotency-Key` header is **required**; reusing a key with a different amount or driver returns `409`. Body: `amount_pkr`, `payment_method` (free text label: no payment provider is integrated), optional `plan_id` |

**Rides**

| Endpoint | Auth | Purpose |
|---|---|---|
| `GET /rides/mine` | any user | Rides of the caller |
| `GET /rides/{id}/detail` | admin, owner patient, assigned driver | Ride with driver, hospital and timeline. The driver sees the patient's phone and mobility needs only while the ride is active |
| `GET /rides/pending` | verified driver | Unassigned rides near the driver |
| `POST /rides/{id}/accept` | verified driver | Atomic claim; `409` if taken. When accepting chooses the hospital, the hospital is pre-alerted afterwards |
| `POST /rides/{id}/rate` | patient | Rate a completed ride (1-5) |
| `GET /rides` | admin | Paged list with filters |
| `GET /rides/export.csv` | admin | CSV export |

`POST /rides/emergency` and `POST /rides/scheduled` accept an optional
`Idempotency-Key` header. A replay returns the original ride; the same key with a
different body returns `409`.

`GET /hospitals` and `GET /hospitals/{id}` are readable without a token; fields
are trimmed for non-admins.

Ride states: `pending`, `driver_assigned`, `driver_en_route`, `patient_picked_up`,
`arrived_at_hospital`, `completed`, `cancelled`. A driver cannot cancel after
pickup (`409`, contact dispatch).

---

## WebSocket

Authentication is the **first message** after connecting, not a query parameter
(so the token never reaches server logs):
```json
{ "token": "<jwt>" }
```
No first message within 5 s closes the socket with code `1008`. A token that is
logged out, from before a "log out everywhere", or for a disabled account is
refused at the handshake and closes an open socket at its next check.

### `WS /ws/driver/{ride_id}`
**Auth:** the driver assigned to that ride. `ride_id` is the ride, not the driver.

Driver streams location:
```json
{ "lat": 33.7005, "lng": 73.0679 }
```
Server replies `{ "ack": true, "lat": ..., "lng": ... }`, or `{ "error": "invalid or too frequent update" }`.
When the ride is no longer live the server sends `{ "event": "ride_ended" }` and closes.

### `WS /ws/ride/{ride_id}`
**Auth:** admin, the patient who owns the ride, or the assigned driver.

Server relays each driver frame `{ "lat": ..., "lng": ... }`, sends
`{ "event": "ping" }` when quiet, and `{ "event": "ride_ended", "status": "<final status>" }`
when the ride completes or is cancelled.

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
