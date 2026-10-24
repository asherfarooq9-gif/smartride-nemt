import { API_URL } from '@/lib/config'

// SECURITY TRADE-OFF: the JWT lives in localStorage, so any script that runs on
// this origin can read it. The nonce-based CSP in proxy.ts is the mitigation
// (no inline or third-party script can run). Moving to an httpOnly, SameSite
// cookie needs a backend session endpoint and CSRF handling, so it is deferred.
const TOKEN_KEY = 'sr_token'
const tokenListeners = new Set<() => void>()

function notifyTokenChange() {
  tokenListeners.forEach(listener => listener())
}

export function getToken(): string | null {
  if (typeof window === 'undefined') return null
  return localStorage.getItem(TOKEN_KEY)
}

export function hasToken(): boolean {
  return getToken() !== null
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token)
  notifyTokenChange()
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY)
  notifyTokenChange()
}

/** Subscribe to token changes in this tab and (via the storage event) other tabs. */
export function subscribeToken(listener: () => void): () => void {
  tokenListeners.add(listener)
  window.addEventListener('storage', listener)
  return () => {
    tokenListeners.delete(listener)
    window.removeEventListener('storage', listener)
  }
}

export function isAbortError(error: unknown): boolean {
  return error instanceof DOMException && error.name === 'AbortError'
}

export function errorMessage(error: unknown, fallback = 'Something went wrong'): string {
  return error instanceof Error ? error.message : fallback
}

async function readJson(res: Response): Promise<Record<string, unknown> | null> {
  try {
    const body: unknown = await res.json()
    return body !== null && typeof body === 'object' ? (body as Record<string, unknown>) : null
  } catch {
    return null
  }
}

/** FastAPI sends `detail` as a string, or as a list of {msg} objects for 422s. */
function describeDetail(detail: unknown): string | null {
  if (typeof detail === 'string') return detail
  if (!Array.isArray(detail)) return null
  const messages = detail
    .map(item => (item && typeof item === 'object' ? (item as { msg?: unknown }).msg : null))
    .filter((msg): msg is string => typeof msg === 'string')
  return messages.length ? messages.join('; ') : null
}

async function failureMessage(res: Response): Promise<string> {
  const body = await readJson(res)
  const detail = describeDetail(body?.detail) ?? (res.statusText || 'Request failed')
  const traceId = typeof body?.trace_id === 'string' ? body.trace_id : res.headers.get('X-Trace-Id')
  // Server faults carry a trace id so support can find the matching log entry.
  return res.status >= 500 && traceId ? `${detail} (reference ${traceId})` : detail
}

async function parseBody<T>(res: Response): Promise<T> {
  const text = await res.text()
  if (!text) return undefined as T // e.g. 204 from /auth/logout
  try {
    return JSON.parse(text) as T
  } catch {
    throw new Error('Unexpected response from the server')
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken()
  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers ?? {}),
    },
  })
  // A 401 from /auth/login means wrong credentials, not an expired session: the
  // form must show the server's message. Otherwise drop the token; AppShell
  // watches the token store and navigates to /login (no hard page reload, and
  // several parallel 401s collapse into one redirect).
  if (res.status === 401 && !path.endsWith('/auth/login')) {
    clearToken()
    throw new Error('Session expired. Please sign in again.')
  }
  if (!res.ok) throw new Error(await failureMessage(res))
  return parseBody<T>(res)
}

function qs(params: Record<string, string | number | boolean | undefined>): string {
  const parts = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== '')
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
  return parts.length ? '?' + parts.join('&') : ''
}

export const api = {
  login: async (phone: string, password: string) => {
    clearToken()
    return request<{ access_token: string; role: string }>('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ phone, password }),
    })
  },

  summary: (signal?: AbortSignal) => request<DashboardSummary>('/api/v1/analytics/summary', { signal }),

  rides: (page = 1, status?: string, ride_type?: string, search?: string, signal?: AbortSignal) =>
    request<{ items: Ride[]; total: number }>(
      `/api/v1/rides${qs({ page, page_size: 20, status, ride_type, search })}`,
      { signal }
    ),

  rideDetail: (id: string, signal?: AbortSignal) =>
    request<RideDetail>(`/api/v1/rides/${encodeURIComponent(id)}/detail`, { signal }),

  cancelRide: (id: string) =>
    request<Ride>(`/api/v1/rides/${encodeURIComponent(id)}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status: 'cancelled' }),
    }),

  drivers: (page = 1, status?: string, is_verified?: string, search?: string, signal?: AbortSignal) =>
    request<{ items: Driver[]; total: number; page: number }>(
      `/api/v1/drivers${qs({ page, page_size: 20, status, is_verified, search })}`,
      { signal }
    ),

  verifyDriver: (id: string, verified: boolean) =>
    request<Driver>(`/api/v1/drivers/${encodeURIComponent(id)}/verify`, {
      method: 'PATCH',
      body: JSON.stringify({ is_verified: verified }),
    }),

  patients: (page = 1, search?: string, signal?: AbortSignal) =>
    request<{ items: Patient[]; total: number }>(
      `/api/v1/patients${qs({ page, page_size: 20, search })}`,
      { signal }
    ),

  hospitals: (page = 1, pageSize = 50, signal?: AbortSignal) =>
    request<{ items: Hospital[]; total: number }>(
      `/api/v1/hospitals${qs({ active_only: false, page, page_size: pageSize })}`,
      { signal }
    ),

  createHospital: (body: HospitalInput) =>
    request<Hospital>('/api/v1/hospitals', { method: 'POST', body: JSON.stringify(body) }),

  updateHospital: (id: string, body: HospitalUpdate) =>
    request<Hospital>(`/api/v1/hospitals/${encodeURIComponent(id)}`, { method: 'PATCH', body: JSON.stringify(body) }),

  logout: () => request<void>('/api/v1/auth/logout', { method: 'POST' }),

  forecast: (city: string, hours = 12, signal?: AbortSignal) =>
    request<ForecastResponse>(`/api/v1/analytics/forecast${qs({ city, hours_ahead: hours })}`, { signal }),

  writeSnapshot: (city: string) =>
    request<unknown>(`/api/v1/analytics/snapshot${qs({ city })}`, { method: 'POST' }),
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
  estimated_fare_pkr: number | null
  final_fare_pkr: number | null
}

export interface RideDetail extends Ride {
  patient: { full_name: string; phone: string; mobility_needs: string | null } | null
  driver: { full_name: string; phone: string; vehicle_plate: string; vehicle_type: string } | null
  hospital: { name: string; address: string; city: string } | null
  triage: {
    symptom_text: string
    predicted_specialty: string
    confidence_score: number | string // the API serialises Decimals as strings
    severity_level: string
  } | null
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

export interface Patient {
  id: string
  user_id: string
  phone: string
  full_name: string
  date_of_birth: string | null
  mobility_needs: string | null
  emergency_contact_name: string | null
  emergency_contact_phone: string | null
  created_at: string
  total_rides?: number
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

/** Body for creating a hospital: real numbers for coordinates, '' for an absent phone. */
export interface HospitalInput {
  name: string
  address: string
  city: string
  lat: number
  lng: number
  ed_capacity: number
  phone: string
  coordinator_phone: string
  specialties: string[]
}

export type HospitalUpdate = Partial<HospitalInput> & { is_active?: boolean }

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
