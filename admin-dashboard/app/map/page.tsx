'use client'
import { useCallback, useMemo } from 'react'
import { api, type Driver, type Hospital, type Ride } from '@/lib/api'
import { ACTIVE_STATUSES } from '@/lib/board'
import { useApiData } from '@/lib/useApiData'
import ErrorBanner from '@/components/ui/ErrorBanner'
import StreetMap, { type Pin, type PinKind as Kind } from '@/components/board/StreetMap'

const POLL_MS = 15_000

interface MapData {
  rides: Ride[]
  drivers: Driver[]
  hospitals: Hospital[]
}

const KIND_LABEL: Record<Kind, string> = {
  emergency: 'Emergency ride',
  ride: 'Active ride',
  available: 'Free driver',
  busy: 'Busy driver',
  hospital: 'Hospital',
}
const KIND_COLOR: Record<Kind, string> = {
  emergency: 'rgb(var(--c-red))',
  ride: 'rgb(var(--c-amber))',
  available: 'rgb(var(--c-green))',
  busy: 'rgb(var(--c-steel))',
  hospital: 'rgb(var(--c-ink))',
}

async function loadMap(signal: AbortSignal): Promise<MapData> {
  const [rideLists, drivers, hospitals] = await Promise.all([
    Promise.all(ACTIVE_STATUSES.map(s => api.rides(1, s, undefined, undefined, signal))),
    api.drivers(1, undefined, undefined, undefined, signal),
    api.hospitals(1, 50, signal),
  ])
  return { rides: rideLists.flatMap(r => r.items), drivers: drivers.items, hospitals: hospitals.items }
}

function toPins({ rides, drivers, hospitals }: MapData): Pin[] {
  const pins: Pin[] = []
  for (const h of hospitals) {
    if (h.is_active) pins.push({ id: `h${h.id}`, kind: 'hospital', lat: h.lat, lng: h.lng, label: h.name })
  }
  for (const r of rides) {
    pins.push({
      id: `r${r.id}`,
      kind: r.ride_type === 'emergency' ? 'emergency' : 'ride',
      lat: r.pickup_lat,
      lng: r.pickup_lng,
      label: `${r.pickup_address ?? 'Pickup'} (${r.status.replaceAll('_', ' ')})`,
    })
  }
  for (const d of drivers) {
    if (d.current_lat == null || d.current_lng == null || d.status === 'offline') continue
    pins.push({
      id: `d${d.id}`,
      kind: d.status === 'available' ? 'available' : 'busy',
      lat: d.current_lat,
      lng: d.current_lng,
      label: `${d.full_name}, ${d.vehicle_plate}`,
    })
  }
  return pins
}

export default function MapPage() {
  const { data, error, loading, refreshing } = useApiData(loadMap, POLL_MS)
  const pins = useMemo(() => (data ? toPins(data) : []), [data])
  const counts = useMemo(() => {
    const c: Record<Kind, number> = { emergency: 0, ride: 0, available: 0, busy: 0, hospital: 0 }
    for (const p of pins) c[p.kind] += 1
    return c
  }, [pins])

  return (
    <div className="space-y-5">
      <div>
        <h1 className="title text-3xl">Live map</h1>
        <p className="mt-1 text-sm text-ink-dim">
          {loading
            ? 'Loading…'
            : `Updates every 15 seconds${refreshing ? ' · refreshing' : ''}. Map by OpenStreetMap.`}
        </p>
      </div>
      <ErrorBanner message={error} />

      <div className="flex flex-wrap gap-x-5 gap-y-2" aria-label="Legend">
        {(Object.keys(KIND_LABEL) as Kind[]).map(k => (
          <span key={k} className="flex items-center gap-2 text-sm text-ink-dim">
            <span aria-hidden="true" className="h-3 w-3 rounded-full" style={{ background: KIND_COLOR[k] }} />
            {KIND_LABEL[k]} <span className="font-medium text-ink">{counts[k]}</span>
          </span>
        ))}
      </div>

      <div className="grid items-start gap-5 lg:grid-cols-[1fr_20rem]">
        <div className="panel-card overflow-hidden p-2">
          <StreetMap pins={pins} />
        </div>

        <aside tabIndex={0} className="panel-card max-h-[34rem] overflow-auto p-4" aria-label="Marker list">
          <h2 className="title mb-3 text-base">What is on the map</h2>
          {pins.length === 0 && !loading ? (
            <p className="text-sm text-ink-dim">Nothing to show yet.</p>
          ) : (
            <ul className="space-y-2.5">
              {pins.map(p => (
                <li key={p.id} className="flex items-start gap-2.5 text-sm">
                  <span aria-hidden="true" className="mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: KIND_COLOR[p.kind] }} />
                  <span>
                    <span className="block text-ink">{p.label}</span>
                    <span className="text-xs text-ink-dim">{KIND_LABEL[p.kind]}</span>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </aside>
      </div>
    </div>
  )
}
