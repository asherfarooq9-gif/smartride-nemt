'use client'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import Link from 'next/link'
import { ArrowRight, Building2, CheckCheck, Clock, Car, HeartPulse, Inbox, Navigation, OctagonAlert, RefreshCw, Search, X, type LucideIcon } from 'lucide-react'
import { api } from '@/lib/api'
import { useApiData } from '@/lib/useApiData'
import {
  ACTIVE_STATUSES,
  belongsToLamp,
  compareUrgency,
  driversTone,
  formatWait,
  isEscalation,
  lampTone,
  tileWord,
  TILE_COPY,
  waitSeconds,
  type LampId,
  type Tone,
} from '@/lib/board'
import ErrorBanner from '@/components/ui/ErrorBanner'
import EmptyState from '@/components/ui/EmptyState'
import Lamp from '@/components/board/Lamp'
import RideLedger from '@/components/board/RideLedger'
import RideDrawer from '@/components/RideDrawer'

const POLL_MS = 15_000
const HISTORY_ROWS = 6
// Rows are re-ranked this often, so a list a dispatcher is aiming at does not shuffle every second.
const RANK_EVERY_MS = 5_000

const TILES: { id: LampId; icon: LucideIcon; shortcut: string }[] = [
  { id: 'unassigned', icon: Clock, shortcut: '1' },
  { id: 'en_route', icon: Navigation, shortcut: '2' },
  { id: 'on_board', icon: HeartPulse, shortcut: '3' },
  { id: 'at_hospital', icon: Building2, shortcut: '4' },
  { id: 'emergency', icon: OctagonAlert, shortcut: '5' },
]

/**
 * One poll of everything the board shows. It also remembers each active ride's status and each
 * tile's tone between polls, so a ride or tile that changed is flagged until a dispatcher
 * acknowledges it. The memory lives in refs read only inside the async fetch, never in render.
 */
function useBoardFetcher() {
  const previousRides = useRef<Map<string, string> | null>(null)
  const previousTones = useRef<Map<LampId, Tone>>(new Map())
  const poll = useRef(0)
  const marks = useRef(new Map<string, number>())

  return useCallback(async (signal: AbortSignal) => {
    const [summary, recent, ...byStatus] = await Promise.all([
      api.summary(signal),
      api.rides(1, undefined, undefined, undefined, signal),
      ...ACTIVE_STATUSES.map(status => api.rides(1, status, undefined, undefined, signal)),
    ])
    const active = byStatus.flatMap(page => page.items)
    const truncated = byStatus.some(page => page.total > page.items.length)
    const nowMs = Date.now()

    if (previousRides.current) {
      poll.current += 1
      for (const ride of active) {
        if (previousRides.current.get(ride.id) !== ride.status) marks.current.set(ride.id, poll.current)
      }
      for (const { id } of TILES) {
        if (isEscalation(previousTones.current.get(id), lampTone(id, active, nowMs))) marks.current.set(`tile:${id}`, poll.current)
      }
    }
    previousRides.current = new Map(active.map(ride => [ride.id, ride.status]))
    previousTones.current = new Map(TILES.map(({ id }) => [id, lampTone(id, active, nowMs)]))

    const history = recent.items.filter(r => r.status === 'completed' || r.status === 'cancelled').slice(0, HISTORY_ROWS)
    return { summary, active, truncated, history, marks: new Map(marks.current), fetchedAt: nowMs }
  }, [])
}

/** Re-renders every second so waits and "updated Ns ago" keep counting between polls. */
function useNow(intervalMs = 1000) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), intervalMs)
    return () => clearInterval(id)
  }, [intervalMs])
  return now
}

/** True for controls that own their own keys. A ride row is a button too, but J/K still work on it. */
function ownsKeys(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false
  if (target.id.startsWith('ride-')) return false
  return target.isContentEditable || target.closest('button, a, input, select, textarea, [role="dialog"]') !== null
}

export default function DashboardPage() {
  const fetchBoard = useBoardFetcher()
  const { data, error, refreshing, reload } = useApiData(fetchBoard, POLL_MS)
  const now = useNow()
  const searchRef = useRef<HTMLInputElement>(null)

  const [filter, setFilter] = useState<LampId | null>(null)
  const [query, setQuery] = useState('')
  const [cursorId, setCursorId] = useState<string | null>(null)
  const [openId, setOpenId] = useState<string | null>(null)
  const [acknowledged, setAcknowledged] = useState<ReadonlyMap<string, number>>(new Map())

  const rankClock = Math.floor(now / RANK_EVERY_MS) * RANK_EVERY_MS
  const sorted = useMemo(() => (data ? [...data.active].sort(compareUrgency(rankClock)) : []), [data, rankClock])
  const visible = useMemo(() => {
    const needle = query.trim().toLowerCase()
    return sorted.filter(r => {
      if (filter && !belongsToLamp(r, filter)) return false
      if (!needle) return true
      return `${r.pickup_address ?? ''} ${r.ride_type} ${r.status}`.toLowerCase().includes(needle)
    })
  }, [sorted, filter, query])

  // Everything flagged since the last look: rides by id, tiles as `tile:<id>`.
  const flagged = useMemo(() => {
    const keys = new Set<string>()
    data?.marks.forEach((mark, key) => {
      if (mark > (acknowledged.get(key) ?? 0)) keys.add(key)
    })
    return keys
  }, [data, acknowledged])
  const changedRides = useMemo(() => new Set([...flagged].filter(k => !k.startsWith('tile:'))), [flagged])

  const acknowledge = useCallback((keys: string[]) => {
    setAcknowledged(prev => {
      const next = new Map(prev)
      for (const key of keys) {
        const mark = data?.marks.get(key)
        if (mark) next.set(key, mark)
      }
      return next
    })
  }, [data])

  const openRide = useCallback((id: string) => {
    setCursorId(id)
    setOpenId(id)
    acknowledge([id]) // Looking at a ride is acknowledging it.
  }, [acknowledge])

  const pressTile = useCallback((id: LampId) => {
    setFilter(f => (f === id ? null : id))
    acknowledge([`tile:${id}`])
  }, [acknowledge])

  // Keyboard: a dispatcher's hands stay on the keys. Controls that own a key keep it.
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.metaKey || e.ctrlKey || e.altKey) return
      const key = e.key.toLowerCase()
      if (key === 'escape') {
        if (openId !== null) return // the panel closes itself
        if (document.activeElement === searchRef.current) return
        setFilter(null)
        return
      }
      if (ownsKeys(e.target)) return
      const index = visible.findIndex(r => r.id === cursorId)
      const move = (to: number) => {
        const ride = visible[Math.min(Math.max(to, 0), visible.length - 1)]
        if (!ride) return
        setCursorId(ride.id)
        // With a ride open, J and K carry the panel along with the cursor.
        if (openId !== null) openRide(ride.id)
        document.getElementById(`ride-${ride.id}`)?.scrollIntoView({ block: 'nearest' })
      }
      const tile = TILES.find(t => t.shortcut === key)
      if (tile) pressTile(tile.id)
      else if (key === 'j' || key === 'arrowdown') { e.preventDefault(); move(index + 1) }
      else if (key === 'k' || key === 'arrowup') { e.preventDefault(); move(index < 0 ? 0 : index - 1) }
      // preventDefault: the panel's own focus move would otherwise let this Enter press click a button.
      else if (key === 'enter' && index >= 0 && openId === null) { e.preventDefault(); openRide(visible[index].id) }
      else if (key === 'a') acknowledge([...flagged])
      else if (key === 'r') reload()
      else if (key === '/') { e.preventDefault(); searchRef.current?.focus() }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [visible, cursorId, openId, flagged, openRide, pressTile, acknowledge, reload])

  if (!data) {
    return error ? (
      <div className="space-y-6">
        <h1 className="title text-3xl">Dashboard</h1>
        <ErrorBanner message={error} />
      </div>
    ) : <BoardSkeleton />
  }

  const { summary, active, truncated, history } = data
  const waiting = active.filter(r => r.status === 'pending')
  const oldestWait = waiting.length ? Math.max(...waiting.map(r => waitSeconds(r, now))) : 0
  const updatedAgo = Math.max(0, Math.floor((now - data.fetchedAt) / 1000))
  const filterLabel = filter ? TILE_COPY[filter].label : null
  const filtering = filterLabel !== null || query.trim() !== ''
  const driverTone = driversTone(summary.available_drivers, waiting.length)

  return (
    <div className={`space-y-6 transition-[padding] duration-[420ms] ease-[var(--spring)] ${openId !== null ? 'xl:pr-[35rem]' : ''}`}>
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="title text-3xl">Dashboard</h1>
          <p role="status" className="mt-1.5 flex items-center gap-2 text-sm text-ink-dim">
            <span aria-hidden="true" className={`h-2 w-2 rounded-full ${error ? 'bg-lamp-red' : 'bg-lamp-green'}`} />
            {error ? 'Connection problem. Showing the last good data.' : 'Live'} · updated {formatWait(updatedAgo)} ago
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-x-5 gap-y-2 text-sm text-ink-dim">
          <span>{summary.total_rides} rides all time</span>
          <span>{summary.active_hospitals} hospitals online</span>
          <span>Avg ETA {summary.avg_eta_seconds_24h != null ? `${Math.round(summary.avg_eta_seconds_24h)}s` : 'not available yet'}</span>
          <button
            type="button"
            onClick={reload}
            disabled={refreshing}
            className="press flex items-center gap-2 rounded-lg border border-edge bg-panel-raised px-3 py-1.5 font-medium text-ink transition-colors hover:border-edge-strong disabled:opacity-50"
          >
            <RefreshCw size={14} className={refreshing ? 'animate-spin' : ''} aria-hidden="true" />
            Refresh
          </button>
        </div>
      </header>

      <ErrorBanner message={error} />

      <section aria-label="Status tiles" className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
        {TILES.map(({ id, icon, shortcut }) => {
          const tone = lampTone(id, active, now)
          return (
            <Lamp
              key={id}
              label={TILE_COPY[id].label}
              icon={icon}
              count={active.filter(r => belongsToLamp(r, id)).length}
              tone={tone}
              word={tileWord(id, tone)}
              detail={id === 'unassigned' && oldestWait > 0 ? `Longest wait ${formatWait(oldestWait)}` : undefined}
              pressed={filter === id}
              onPress={() => pressTile(id)}
              shortcut={shortcut}
              flashing={flagged.has(`tile:${id}`)}
            />
          )
        })}
        <Lamp
          label={TILE_COPY.drivers.label}
          icon={Car}
          count={summary.available_drivers}
          tone={driverTone}
          word={tileWord('drivers', driverTone)}
          detail={`of ${summary.total_drivers} drivers`}
          href="/drivers"
        />
      </section>

      <section aria-labelledby="active-heading" className="panel-card overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-edge px-4 py-3">
          <div className="flex flex-wrap items-center gap-3">
            <h2 id="active-heading" className="title text-lg">Active rides</h2>
            <span className="text-sm text-ink-dim">{filtering ? `${visible.length} of ${active.length}` : active.length}</span>
            {filterLabel && (
              <button
                type="button"
                onClick={() => setFilter(null)}
                className="press flex items-center gap-1.5 rounded-full border border-steel/40 bg-steel/10 py-0.5 pl-3 pr-2 text-xs font-medium text-steel"
              >
                {filterLabel}
                <X size={12} aria-hidden="true" />
                <span className="sr-only">Clear filter</span>
              </button>
            )}
          </div>
          <div className="flex items-center gap-3">
            {flagged.size > 0 && (
              <button
                type="button"
                onClick={() => acknowledge([...flagged])}
                className="press flex items-center gap-2 rounded-lg border border-lamp-amber/50 bg-lamp-amber/10 px-3 py-1.5 text-sm font-medium text-lamp-amber"
              >
                <CheckCheck size={14} aria-hidden="true" />
                Acknowledge {flagged.size} {flagged.size === 1 ? 'change' : 'changes'}
              </button>
            )}
            <label className="relative">
              <span className="sr-only">Search active rides by pickup</span>
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-dim" aria-hidden="true" />
              <input
                ref={searchRef}
                type="search"
                value={query}
                onChange={e => setQuery(e.target.value)}
                onKeyDown={e => {
                  if (e.key === 'Escape') { setQuery(''); e.currentTarget.blur() }
                }}
                placeholder="Search pickup  (/)"
                className="w-56 rounded-lg border py-1.5 pl-9 pr-3 text-sm transition-[width] duration-300 ease-[var(--spring)] focus:w-72 focus:border-steel focus:outline-none focus:ring-2 focus:ring-steel/30"
              />
            </label>
          </div>
        </div>
        {visible.length === 0 ? (
          <EmptyState
            icon={Inbox}
            title={filtering ? 'No rides match' : 'No active rides'}
            description={
              filtering
                ? 'Clear the filter or the search to see every active ride.'
                : 'A ride appears here the moment a patient requests one. A tile turns red or amber only when a ride needs a person.'
            }
          />
        ) : (
          <RideLedger rides={visible} nowMs={now} changed={changedRides} cursorId={cursorId} onOpen={openRide} />
        )}
        {truncated && (
          <p className="border-t border-edge px-4 py-2 text-xs text-ink-dim">
            Showing the first 20 rides of each status. Open <Link href="/rides" className="text-steel underline">Rides</Link> for the full list.
          </p>
        )}
      </section>

      <section aria-labelledby="closed-heading" className="panel-card overflow-hidden">
        <div className="flex items-center justify-between border-b border-edge px-4 py-3">
          <h2 id="closed-heading" className="title text-lg">Recently closed</h2>
          <Link href="/rides" className="flex items-center gap-1 text-sm font-medium text-steel hover:underline">
            All rides <ArrowRight size={14} aria-hidden="true" />
          </Link>
        </div>
        {history.length === 0 ? (
          <p className="px-4 py-6 text-sm text-ink-dim">No completed or cancelled rides yet.</p>
        ) : (
          <RideLedger rides={history} nowMs={now} changed={new Set()} cursorId={cursorId} onOpen={openRide} closed />
        )}
      </section>

      <p className="hidden text-xs text-ink-dim lg:block">
        Keys: <kbd className="legend">J</kbd>/<kbd className="legend">K</kbd> move · <kbd className="legend">Enter</kbd> open ·{' '}
        <kbd className="legend">1–5</kbd> filter · <kbd className="legend">/</kbd> search · <kbd className="legend">A</kbd> acknowledge ·{' '}
        <kbd className="legend">R</kbd> refresh · <kbd className="legend">Esc</kbd> close
      </p>

      <RideDrawer rideId={openId} onClose={() => setOpenId(null)} onCancelled={reload} />
    </div>
  )
}

// Same blocks as the loaded board, so nothing shifts when the data arrives.
function BoardSkeleton() {
  return (
    <div className="animate-pulse space-y-6" role="status" aria-label="Loading dashboard">
      <div className="space-y-2">
        <div className="h-8 w-44 rounded bg-edge" />
        <div className="h-4 w-56 rounded bg-edge" />
      </div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="h-[5.5rem] rounded-lg border border-edge bg-panel-raised" />
        ))}
      </div>
      <div className="panel-card h-80" />
    </div>
  )
}
