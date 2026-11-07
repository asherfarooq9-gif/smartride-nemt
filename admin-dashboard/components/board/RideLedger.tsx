import type { Ride } from '@/lib/api'
import { formatWait, rideState, rideTone, waitSeconds, type Tone } from '@/lib/board'
import StatusBadge from '@/components/ui/StatusBadge'

const GRID = 'grid grid-cols-[1fr_auto] items-center gap-x-4 gap-y-1 md:grid-cols-[11rem_6rem_5rem_minmax(0,1fr)_minmax(0,1fr)]'

const TONE_TEXT: Record<Tone, string> = {
  alert: 'text-lamp-red',
  attention: 'text-lamp-amber',
  normal: 'text-ink',
  info: 'text-ink',
  idle: 'text-ink-dim',
}

interface Props {
  rides: Ride[]
  nowMs: number
  /** Ride id -> the poll in which its status last changed, for rides not yet acknowledged. */
  changed: ReadonlySet<string>
  cursorId: string | null
  onOpen: (id: string) => void
  /** Closed rides show how long they took instead of how long they have waited. */
  closed?: boolean
}

function pickup(ride: Ride): string {
  return ride.pickup_address ?? `${ride.pickup_lat.toFixed(4)}, ${ride.pickup_lng.toFixed(4)}`
}

export default function RideLedger({ rides, nowMs, changed, cursorId, onOpen, closed = false }: Props) {
  return (
    <div>
      <div aria-hidden="true" className={`${GRID} hidden border-b border-edge px-4 py-2 md:grid`}>
        <span className="legend text-[0.7rem]">Status</span>
        <span className="legend text-[0.7rem]">Type</span>
        <span className="legend text-[0.7rem]">{closed ? 'Took' : 'Waiting'}</span>
        <span className="legend text-[0.7rem]">Pickup</span>
        <span className="legend text-[0.7rem]">Situation</span>
      </div>
      <ul className="divide-y divide-edge">
        {rides.map(ride => {
          const tone = closed ? 'idle' : rideTone(ride, nowMs)
          const isChanged = changed.has(ride.id)
          const elapsed = closed
            ? Math.max(0, Math.floor((Date.parse(ride.completed_at ?? ride.requested_at) - Date.parse(ride.requested_at)) / 1000))
            : waitSeconds(ride, nowMs)
          return (
            <li key={ride.id}>
              <button
                type="button"
                id={`ride-${ride.id}`}
                onClick={() => onOpen(ride.id)}
                aria-current={cursorId === ride.id ? 'true' : undefined}
                className={`${GRID} w-full px-4 py-3 text-left text-sm transition-colors hover:bg-panel-inset active:bg-steel/10 ${
                  cursorId === ride.id ? 'bg-steel/[0.06] outline outline-2 -outline-offset-2 outline-steel' : ''
                }`}
              >
                <span className="flex items-center gap-2">
                  <StatusBadge value={ride.status} />
                  <span className={`legend text-[0.72rem] md:hidden ${ride.ride_type === 'emergency' ? '!text-lamp-red' : ''}`}>
                    {ride.ride_type}
                  </span>
                  {isChanged && (
                    <span className="legend flex items-center gap-1 text-[0.68rem] !text-lamp-amber">
                      <span aria-hidden="true" className="lamp-attn h-1.5 w-1.5 rounded-[1px] bg-lamp-amber" />
                      Changed
                    </span>
                  )}
                </span>
                <span className={`legend hidden text-[0.75rem] md:block ${ride.ride_type === 'emergency' ? '!text-lamp-red' : ''}`}>
                  {ride.ride_type}
                </span>
                <span className={`font-medium ${TONE_TEXT[tone]}`}>{formatWait(elapsed)}</span>
                <span className="col-span-2 truncate text-ink-dim md:col-span-1">{pickup(ride)}</span>
                <span className={`col-span-2 truncate md:col-span-1 ${TONE_TEXT[tone]}`}>{rideState(ride, nowMs)}</span>
              </button>
            </li>
          )
        })}
      </ul>
    </div>
  )
}
