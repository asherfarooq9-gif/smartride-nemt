import fs from 'node:fs'
import path from 'node:path'
import { ADMIN, PROJECTS, RIDE_ADDRESS, TEST_PATIENT, login, post, testDriver } from './api'

/** Seed a patient, an unverified driver and one pending emergency ride, then save an admin session. */
export default async function globalSetup() {
  const patient = await post<{ access_token: string }>('/api/v1/auth/register', { ...TEST_PATIENT, role: 'patient' })
  for (const project of PROJECTS) {
    await post('/api/v1/auth/register', { ...testDriver(project), role: 'driver' })
    await post('/api/v1/auth/register', { ...testDriver(project, true), role: 'driver' })
  }
  await post(
    '/api/v1/rides/emergency',
    { symptom_text: 'chest pain', pickup_lat: 33.7215, pickup_lng: 73.0433, pickup_address: RIDE_ADDRESS },
    patient.access_token,
  )

  const adminToken = await login(ADMIN.phone, ADMIN.password)
  const file = path.join(__dirname, '.auth', 'admin.json')
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(
    file,
    JSON.stringify({
      cookies: [],
      origins: [{ origin: 'http://localhost:13100', localStorage: [{ name: 'sr_token', value: adminToken }] }],
    }),
  )
}
