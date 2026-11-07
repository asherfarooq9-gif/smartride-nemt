'use client'
import Link from 'next/link'
import { useCallback } from 'react'
import { Siren } from 'lucide-react'
import { api } from '@/lib/api'
import { useApiData } from '@/lib/useApiData'

const POLL_MS = 15_000

/** A red bar on every page while an emergency ride has no driver. Silent when the check fails: the dashboard shows errors. */
export default function EmergencyBanner() {
  const fetcher = useCallback((signal: AbortSignal) => api.rides(1, 'pending', 'emergency', undefined, signal), [])
  const { data } = useApiData(fetcher, POLL_MS)
  const count = data?.total ?? 0
  if (count === 0) return null
  return (
    <div role="alert" className="shrink-0">
      <Link
        href="/rides"
        className="flex items-center justify-center gap-2 bg-lamp-red px-4 py-2 text-sm font-semibold text-white"
      >
        <Siren size={16} aria-hidden="true" />
        {count === 1 ? '1 emergency ride is waiting for a driver' : `${count} emergency rides are waiting for a driver`}
        <span className="underline">View</span>
      </Link>
    </div>
  )
}
