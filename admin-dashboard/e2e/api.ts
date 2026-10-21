export const API_URL = 'http://localhost:18010'
export const ADMIN = { phone: '+92300000001', password: 'admin123' }

export const TEST_PATIENT = { phone: '+923001110001', password: 'patient123', full_name: 'E2E Patient' }
export const PROJECTS = ['desktop', 'tablet', 'mobile']

/** One unverified driver per viewport project, so each can verify its own without sharing state. */
export function testDriver(project: string, spare = false) {
  const n = PROJECTS.indexOf(project) + 1 + (spare ? 10 : 0)
  return {
    phone: `+92300122${String(n).padStart(4, '0')}`,
    password: 'driver1234',
    full_name: `${spare ? 'E2E Spare' : 'E2E Driver'} ${project}`,
    license_no: `E2E-LIC-${n}`,
    vehicle_plate: `E2E-${n}`,
    vehicle_type: 'sedan',
  }
}
export const RIDE_ADDRESS = 'E2E Test Street 42'

export async function post<T>(path: string, body: unknown, token?: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`POST ${path} -> ${res.status} ${await res.text()}`)
  return res.json() as Promise<T>
}

export async function login(phone: string, password: string): Promise<string> {
  const { access_token } = await post<{ access_token: string }>('/api/v1/auth/login', { phone, password })
  return access_token
}
