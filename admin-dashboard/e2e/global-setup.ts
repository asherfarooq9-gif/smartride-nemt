import fs from 'node:fs'
import path from 'node:path'
import {
  ADMIN, ADMIN_URL, BULK_RIDE_ADDRESS, BULK_RIDE_COUNT, PROJECTS, RIDE_ADDRESS, TEST_PATIENT,
  cancelRideAddress, login, post, testDriver,
} from './api'

/** The API allows one active emergency ride per patient, so every ride gets its own patient. */
async function requestRideAsNewPatient(index: number, full_name: string, pickup_address: string) {
  const patient = { phone: `+92300333${String(index).padStart(4, '0')}`, password: 'patient123', full_name }
  const { access_token } = await post<{ access_token: string }>('/api/v1/auth/register', { ...patient, role: 'patient' })
  await requestRide(access_token, pickup_address)
}

async function requestRide(token: string, pickup_address: string) {
  await post(
    '/api/v1/rides/emergency',
    { symptom_text: 'chest pain', pickup_lat: 33.7215, pickup_lng: 73.0433, pickup_address },
    token,
  )
}

/** Seed drivers, patients and rides, then save an admin session. */
export default async function globalSetup() {
  for (const project of PROJECTS) {
    await post('/api/v1/auth/register', { ...testDriver(project), role: 'driver' })
    await post('/api/v1/auth/register', { ...testDriver(project, true), role: 'driver' })
  }
  // The rides and patients lists are newest-first: create the bulk ones first so
  // the rows the tests look for sit on page 1.
  let index = 0
  for (let i = 0; i < BULK_RIDE_COUNT; i++) {
    await requestRideAsNewPatient(index++, `Bulk Rider ${i}`, BULK_RIDE_ADDRESS)
  }
  for (const project of PROJECTS) {
    await requestRideAsNewPatient(index++, `Cancel Rider ${project}`, cancelRideAddress(project))
  }
  const patient = await post<{ access_token: string }>('/api/v1/auth/register', { ...TEST_PATIENT, role: 'patient' })
  await requestRide(patient.access_token, RIDE_ADDRESS)

  const adminToken = await login(ADMIN.phone, ADMIN.password)
  const file = path.join(__dirname, '.auth', 'admin.json')
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(
    file,
    JSON.stringify({
      cookies: [],
      origins: [{ origin: ADMIN_URL, localStorage: [{ name: 'sr_token', value: adminToken }] }],
    }),
  )
}
