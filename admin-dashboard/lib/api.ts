const BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000'

export function getToken(): string | null {
  if (typeof window === 'undefined') return null
  return localStorage.getItem('sr_token')
}

export function setToken(token: string) {
  localStorage.setItem('sr_token', token)
}

export function clearToken() {
  localStorage.removeItem('sr_token')
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken()
  const res = await fetch(`${BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers ?? {}),
    },
  })
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }))
    throw new Error(err.detail ?? 'Request failed')
  }
  return res.json()
}

export const api = {
  login: (phone: string, password: string) =>
    request<{ access_token: string; role: string }>('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ phone, password }),
    }),

  summary: () => request<DashboardSummary>('/api/v1/analytics/summary'),

  rides: (page = 1) =>
    request<{ items: Ride[]; total: number }>(`/api/v1/rides?page=${page}&page_size=20`),

  drivers: (page = 1) =>
    request<{ items: Driver[]; total: number; page: number }>(
      `/api/v1/drivers?page=${page}&page_size=20`
    ),

  verifyDriver: (id: string) =>
    request<Driver>(`/api/v1/drivers/${id}/verify`, { method: 'PATCH' }),

  hospitals: () => request<{ items: Hospital[]; total: number }>('/api/v1/hospitals?active_only=false'),

  createHospital: (body: Partial<Hospital>) =>
    request<Hospital>('/api/v1/hospitals', { method: 'POST', body: JSON.stringify(body) }),

  updateHospital: (id: string, body: Partial<Hospital>) =>
    request<Hospital>(`/api/v1/hospitals/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),

  forecast: (city: string, hours = 12) =>
    request<ForecastResponse>(`/api/v1/analytics/forecast?city=${city}&hours_ahead=${hours}`),

  writeSnapshot: (city: string) =>
    request<unknown>(`/api/v1/analytics/snapshot?city=${city}`, { method: 'POST' }),
}

// ── Types ─────────────────────────────────────────────────────────────────────
export interface Ride {
  id: string
  patient_id: string
  driver_id: string | null
  hospital_id: string | null
  ride_type: string
  status: string
  pickup_lat: number
  pickup_lng: number
  pickup_address: string | null
  requested_at: string
  driver_assigned_at: string | null
  completed_at: string | null
}

export interface Driver {
  id: string
  phone: string
  full_name: string
  license_no: string
  vehicle_plate: string
  vehicle_type: string
  is_verified: boolean
  status: string
  current_lat: number | null
  current_lng: number | null
  last_seen_at: string | null
  created_at: string
}

export interface Hospital {
  id: string
  name: string
  address: string
  city: string
  lat: number
  lng: number
  phone: string | null
  specialties: string[]
  ed_capacity: number
  ed_current_load: number
  fhir_endpoint: string | null
  coordinator_phone: string | null
  is_active: boolean
  created_at: string
}

export interface DashboardSummary {
  total_rides: number
  emergency_rides_24h: number
  active_rides: number
  available_drivers: number
  total_drivers: number
  active_hospitals: number
  avg_eta_seconds_24h: number | null
  snapshot_at: string
}

export interface ForecastResponse {
  city: string
  generated_at: string
  method: string
  forecast: { hour: string; predicted_rides: number }[]
}
