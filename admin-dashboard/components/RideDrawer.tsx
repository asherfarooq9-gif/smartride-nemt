'use client'
import { useCallback } from 'react'
import { api, type RideDetail } from '@/lib/api'
import { useApiData } from '@/lib/useApiData'
import SidePanel from '@/components/ui/SidePanel'
import ErrorBanner from '@/components/ui/ErrorBanner'
import RideDetailView from '@/app/rides/RideDetailView'

interface Props {
  rideId: string | null
  onClose: () => void
  /** Called after the ride was cancelled, once the drawer has closed. */
  onCancelled: () => void
}

/** A ride's full record in a side panel that sits beside the board instead of covering it. */
export default function RideDrawer({ rideId, onClose, onCancelled }: Props) {
  const fetchDetail = useCallback(
    (signal: AbortSignal): Promise<RideDetail | null> => (rideId ? api.rideDetail(rideId, signal) : Promise.resolve(null)),
    [rideId],
  )
  const { data: detail, error, loading, reload } = useApiData(fetchDetail)

  return (
    <SidePanel open={rideId !== null} onClose={onClose} title="Ride Details">
      {loading && (
        <div className="animate-pulse space-y-3" role="status" aria-label="Loading ride details">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="h-10 rounded bg-panel-inset" />
          ))}
        </div>
      )}
      <ErrorBanner message={error} />
      {error && (
        <button type="button" onClick={reload} className="mt-3 text-sm text-steel hover:underline">
          Try again
        </button>
      )}
      {!loading && detail && <RideDetailView ride={detail} onCancelled={() => { onClose(); onCancelled() }} />}
    </SidePanel>
  )
}
