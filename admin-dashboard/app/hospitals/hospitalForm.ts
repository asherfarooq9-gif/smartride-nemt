import type { Hospital, HospitalInput } from '@/lib/api'

/**
 * What the hospital form holds while it is being edited. The numeric fields stay as
 * the text the admin typed, because parsing on every keystroke turns a cleared or
 * half-typed field ("", "-") into 0, and 0, 0 is a point in the sea.
 */
export interface HospitalFormState {
  name: string
  address: string
  city: string
  lat: string
  lng: string
  ed_capacity: string
  phone: string
  coordinator_phone: string
  specialties: string[]
}

export const EMPTY_FORM: HospitalFormState = {
  name: '', address: '', city: 'Islamabad',
  lat: '33.6844', lng: '73.0479', ed_capacity: '100',
  specialties: [], phone: '', coordinator_phone: '',
}

export function toForm(h: Hospital): HospitalFormState {
  return {
    name: h.name, address: h.address, city: h.city,
    lat: String(h.lat), lng: String(h.lng), ed_capacity: String(h.ed_capacity),
    phone: h.phone ?? '', coordinator_phone: h.coordinator_phone ?? '',
    specialties: [...h.specialties],
  }
}

export type ParsedHospital = { ok: true; value: HospitalInput } | { ok: false; error: string }

function toNumber(text: string): number {
  // Number('') is 0 and Number('  ') is 0: an empty field must not look like a value.
  return text.trim() === '' ? NaN : Number(text)
}

/** Validates the form and returns numbers, or says what to fix. Used by create and edit. */
export function parseHospitalForm(form: HospitalFormState): ParsedHospital {
  if (!form.name.trim() || !form.address.trim() || !form.city.trim()) {
    return { ok: false, error: 'Name, address and city are required' }
  }
  const lat = toNumber(form.lat)
  const lng = toNumber(form.lng)
  if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
    return { ok: false, error: 'Latitude must be a number between -90 and 90' }
  }
  if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
    return { ok: false, error: 'Longitude must be a number between -180 and 180' }
  }
  if (lat === 0 && lng === 0) {
    return { ok: false, error: 'Latitude and longitude 0, 0 is not a real location' }
  }
  const capacity = toNumber(form.ed_capacity)
  if (!Number.isInteger(capacity) || capacity < 1) {
    return { ok: false, error: 'ED capacity must be a whole number of at least 1' }
  }
  return {
    ok: true,
    value: {
      name: form.name.trim(), address: form.address.trim(), city: form.city.trim(),
      lat, lng, ed_capacity: capacity,
      phone: form.phone.trim(), coordinator_phone: form.coordinator_phone.trim(),
      specialties: form.specialties,
    },
  }
}
