import type { Ride } from '@/lib/api'

/** How a status reads on the panel. A tone is always shown with a word, never alone. */
export type Tone = 'alert' | 'attention' | 'normal' | 'info' | 'idle'

export const RIDE_STATUS: Record<string, Tone> = {
  pending: 'attention',
  driver_assigned: 'info',
  driver_en_route: 'info',
  patient_picked_up: 'info',
  arrived_at_hospital: 'normal',
  completed: 'normal',
  cancelled: 'idle',
}

export const DRIVER_STATUS: Record<string, Tone> = {
  available: 'normal',
  busy: 'info',
  offline: 'idle',
}

export const ACTIVE_STATUSES = [
  'pending',
  'driver_assigned',
  'driver_en_route',
  'patient_picked_up',
  'arrived_at_hospital',
] as const

// Operational defaults for when a lamp lights. They are product decisions, so they
// are named here, in one place, for the dispatch lead to confirm or change.
export const EMERGENCY_UNASSIGNED_ALERT_SECONDS = 60
export const UNASSIGNED_ALERT_SECONDS = 180
export const DRIVER_STALL_MINUTES = 30
export const TRIP_STALL_MINUTES = 90

export type LampId = 'unassigned' | 'en_route' | 'on_board' | 'at_hospital' | 'emergency'

const LAMP_STATUSES: Record<Exclude<LampId, 'emergency'>, readonly string[]> = {
  unassigned: ['pending'],
  en_route: ['driver_assigned', 'driver_en_route'],
  on_board: ['patient_picked_up'],
  at_hospital: ['arrived_at_hospital'],
}

export function belongsToLamp(ride: Ride, lamp: LampId): boolean {
  if (lamp === 'emergency') return ride.ride_type === 'emergency'
  return LAMP_STATUSES[lamp].includes(ride.status)
}

const SEVERITY: Record<Tone, number> = { alert: 4, attention: 3, info: 2, normal: 1, idle: 0 }

export function worstTone(tones: Tone[]): Tone {
  return tones.reduce<Tone>((worst, t) => (SEVERITY[t] > SEVERITY[worst] ? t : worst), 'idle')
}

function seconds(from: string | null, nowMs: number): number {
  const start = from ? Date.parse(from) : NaN
  return Number.isFinite(start) ? Math.max(0, Math.floor((nowMs - start) / 1000)) : 0
}

/** Seconds since the patient asked for the ride. */
export function waitSeconds(ride: Ride, nowMs: number): number {
  return seconds(ride.requested_at, nowMs)
}

/** What a dispatcher should make of this ride right now. */
export function rideTone(ride: Ride, nowMs: number): Tone {
  const waited = waitSeconds(ride, nowMs)
  switch (ride.status) {
    case 'pending': {
      const limit = ride.ride_type === 'emergency' ? EMERGENCY_UNASSIGNED_ALERT_SECONDS : UNASSIGNED_ALERT_SECONDS
      return waited >= limit ? 'alert' : 'attention'
    }
    case 'driver_assigned':
    case 'driver_en_route': {
      const sinceAssigned = seconds(ride.driver_assigned_at ?? ride.requested_at, nowMs)
      return sinceAssigned >= DRIVER_STALL_MINUTES * 60 ? 'attention' : 'info'
    }
    case 'patient_picked_up':
      return waited >= TRIP_STALL_MINUTES * 60 ? 'attention' : 'info'
    case 'arrived_at_hospital':
      return 'normal'
    default:
      return 'idle'
  }
}

/** One plain remark beside the status, so the list says whether to worry. */
export function rideState(ride: Ride, nowMs: number): string {
  const slow = rideTone(ride, nowMs) === 'attention'
  switch (ride.status) {
    case 'pending':
      return rideTone(ride, nowMs) === 'alert' ? 'No driver yet, overdue' : 'Finding a driver'
    case 'driver_assigned':
      return slow ? 'Slow to start' : 'On track'
    case 'driver_en_route':
      return slow ? 'Taking long' : 'On track'
    case 'patient_picked_up':
      return slow ? 'Trip is long' : 'On track'
    case 'arrived_at_hospital':
      return 'Arrived'
    case 'completed':
      return 'Completed'
    case 'cancelled':
      return 'Cancelled'
    default:
      return ride.status.replace(/_/g, ' ')
  }
}

const STATUS_LABEL: Record<string, string> = {
  pending: 'Waiting for driver',
  driver_assigned: 'Driver assigned',
  driver_en_route: 'Driver on the way',
  patient_picked_up: 'Patient on board',
  arrived_at_hospital: 'At hospital',
  completed: 'Completed',
  cancelled: 'Cancelled',
  available: 'Available',
  busy: 'Busy',
  offline: 'Offline',
}

/** A status in plain words, falling back to the raw value with spaces. */
export function statusLabel(value: string): string {
  return STATUS_LABEL[value] ?? value.replace(/_/g, ' ')
}

/** Loudest first: tone, then emergencies, then whoever has waited longest. */
export function compareUrgency(nowMs: number) {
  return (a: Ride, b: Ride): number => {
    const byTone = SEVERITY[rideTone(b, nowMs)] - SEVERITY[rideTone(a, nowMs)]
    if (byTone !== 0) return byTone
    const emergency = Number(b.ride_type === 'emergency') - Number(a.ride_type === 'emergency')
    if (emergency !== 0) return emergency
    return waitSeconds(b, nowMs) - waitSeconds(a, nowMs)
  }
}

export function formatWait(totalSeconds: number): string {
  if (totalSeconds < 60) return `${totalSeconds}s`
  const minutes = Math.floor(totalSeconds / 60)
  if (minutes < 60) return `${minutes} min`
  const hours = Math.floor(minutes / 60)
  return `${hours} h ${minutes % 60} min`
}

/** A lamp lights for the worst ride behind it; with rides but none in need, it reads calm. */
export function lampTone(lamp: LampId, rides: Ride[], nowMs: number): Tone {
  const behind = rides.filter(r => belongsToLamp(r, lamp))
  if (behind.length === 0) return 'idle'
  const worst = worstTone(behind.map(r => rideTone(r, nowMs)))
  if (SEVERITY[worst] >= SEVERITY.attention) return worst
  // Nothing needs a person. Emergencies stay marked so they are never missed; the rest read calm.
  return lamp === 'emergency' ? 'info' : 'normal'
}

/** No free driver while a ride is waiting is the one driver state that needs a person. */
export function driversTone(available: number, waiting: number): Tone {
  if (available > 0) return 'normal'
  return waiting > 0 ? 'alert' : 'attention'
}

export type TileId = LampId | 'drivers'

/** Plain words for each tile, so the wall reads without a legend. Tone picks the word. */
export const TILE_COPY: Record<TileId, { label: string; words: Partial<Record<Tone, string>> }> = {
  unassigned: { label: 'Waiting for a driver', words: { idle: 'None waiting', attention: 'Waiting', alert: 'Overdue' } },
  en_route: { label: 'Driver on the way', words: { idle: 'None on the way', normal: 'On track', attention: 'Running slow' } },
  on_board: { label: 'Patient on board', words: { idle: 'None on board', normal: 'On track', attention: 'Trip is long' } },
  at_hospital: { label: 'At the hospital', words: { idle: 'None arriving', normal: 'Arrived' } },
  emergency: { label: 'Emergencies', words: { idle: 'None active', info: 'Active', attention: 'Needs action', alert: 'Needs action now' } },
  drivers: { label: 'Drivers free', words: { normal: 'Available', attention: 'None free', alert: 'None free, rides waiting' } },
}

export function tileWord(id: TileId, tone: Tone): string {
  return TILE_COPY[id].words[tone] ?? 'Active'
}

/** Quiet tones stay white; only a tone that needs a person (or marks an emergency) is tinted. */
export function isLit(tone: Tone): boolean {
  return tone === 'alert' || tone === 'attention' || tone === 'info'
}

/** A tone that just got worse is what flashes until someone acknowledges it. */
export function isEscalation(before: Tone | undefined, after: Tone): boolean {
  return (after === 'alert' || after === 'attention') && SEVERITY[after] > SEVERITY[before ?? 'idle']
}
