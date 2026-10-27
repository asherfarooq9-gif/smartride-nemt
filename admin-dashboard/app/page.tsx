'use client'
import { api } from '@/lib/api'
import { useApiData } from '@/lib/useApiData'
import ErrorBanner from '@/components/ui/ErrorBanner'
import StatCard from '@/components/ui/StatCard'
import StatusBadge from '@/components/ui/StatusBadge'
import { Car, AlertCircle, Activity, Users, Building2, Clock, TrendingUp, RefreshCw } from 'lucide-react'
import Link from 'next/link'

const POLL_MS = 30_000

async function fetchDashboard(signal: AbortSignal) {
  const [summary, rides] = await Promise.all([api.summary(signal), api.rides(1, undefined, undefined, undefined, signal)])
  return { summary, recent: rides.items.slice(0, 8) }
}

export default function DashboardPage() {
  const { data, error, refreshing, reload } = useApiData(fetchDashboard, POLL_MS)

  if (!data) {
    return error ? (
      <div className="space-y-6">
        <h1 className="text-2xl font-bold text-blue-900">Dashboard</h1>
        <ErrorBanner message={error} />
      </div>
    ) : <DashboardSkeleton />
  }
  const { summary, recent } = data

  const cards = [
    { label: 'Total Rides', value: summary.total_rides, icon: Car, color: 'blue' },
    { label: 'Emergency (24 h)', value: summary.emergency_rides_24h, icon: AlertCircle, color: 'red' },
    { label: 'Active Rides', value: summary.active_rides, icon: Activity, color: 'amber' },
    { label: 'Available Drivers', value: summary.available_drivers, icon: Users, color: 'green' },
    { label: 'Total Drivers', value: summary.total_drivers, icon: Users, color: 'gray' },
    { label: 'Hospitals Online', value: summary.active_hospitals, icon: Building2, color: 'purple' },
  ]

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-blue-900">Dashboard</h1>
          <p className="text-sm text-gray-600 mt-0.5">
            Last updated: {new Date(summary.snapshot_at).toLocaleString()}
          </p>
        </div>
        <button
          type="button"
          onClick={reload}
          disabled={refreshing}
          className="flex items-center gap-2 text-sm bg-white border border-gray-200 hover:border-blue-300 px-4 py-2 rounded-xl shadow-sm transition disabled:opacity-50"
        >
          <RefreshCw size={14} className={refreshing ? 'animate-spin' : ''} aria-hidden="true" />
          Refresh
        </button>
      </div>

      <ErrorBanner message={error} />

      {/* Stat Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        {cards.map(c => (
          <StatCard key={c.label} label={c.label} value={c.value} icon={c.icon} color={c.color} />
        ))}
      </div>

      {/* ETA card. The slot keeps its height when there is no ETA yet, so the table
          below does not move between the loading skeleton and the loaded page. */}
      <div className="min-h-[92px]">
        {summary.avg_eta_seconds_24h != null && (
          <div className="bg-white rounded-2xl border border-blue-100 p-5 shadow-sm inline-flex items-center gap-4">
            <div className="p-3 bg-cyan-50 border border-cyan-200 rounded-xl text-cyan-700">
              <Clock size={20} />
            </div>
            <div>
              <p className="text-xs font-medium text-gray-500 uppercase tracking-wider">Avg ETA (24 h)</p>
              <p className="text-3xl font-bold text-gray-900">{Math.round(summary.avg_eta_seconds_24h)}s</p>
            </div>
          </div>
        )}
      </div>

      {/* Recent Rides */}
      <div className="bg-white rounded-2xl border border-blue-100 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-6 py-4 border-b border-blue-100">
          <div className="flex items-center gap-2">
            <TrendingUp size={16} className="text-blue-600" />
            <h2 className="font-semibold text-gray-900">Recent Rides</h2>
          </div>
          <Link href="/rides" className="text-xs text-blue-600 hover:underline font-medium">View all →</Link>
        </div>
        <table className="w-full text-sm">
          <thead className="bg-blue-50 text-blue-600 text-xs uppercase">
            <tr>
              {['ID', 'Type', 'Status', 'Pickup', 'Requested'].map(h => (
                <th key={h} className="px-4 py-3 text-left font-medium">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-blue-50">
            {recent.map(r => (
              <tr key={r.id} className="hover:bg-gray-50 transition-colors">
                <td className="px-4 py-3 font-mono text-xs text-gray-500">{r.id.slice(0, 8)}…</td>
                <td className="px-4 py-3">
                  <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${r.ride_type === 'emergency' ? 'bg-red-100 text-red-700' : 'bg-blue-100 text-blue-700'}`}>
                    {r.ride_type}
                  </span>
                </td>
                <td className="px-4 py-3"><StatusBadge value={r.status} /></td>
                <td className="px-4 py-3 text-gray-600 text-xs max-w-[200px] truncate">
                  {r.pickup_address ?? `${r.pickup_lat.toFixed(4)}, ${r.pickup_lng.toFixed(4)}`}
                </td>
                <td className="px-4 py-3 text-gray-500 text-xs">{new Date(r.requested_at).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

// Mirrors the loaded page block for block (header, six cards, ETA slot, rides table
// with the rows it will show) so nothing shifts when the data arrives. Heights are
// approximate; re-measure with Lighthouse if the layout above changes.
const RECENT_ROWS = 8

function DashboardSkeleton() {
  return (
    <div className="space-y-8 animate-pulse" role="status" aria-label="Loading dashboard">
      <div className="flex items-center justify-between">
        <div className="space-y-2">
          <div className="h-8 bg-gray-200 rounded w-48" />
          <div className="h-4 bg-gray-200 rounded w-56" />
        </div>
        <div className="h-10 bg-gray-200 rounded-xl w-28" />
      </div>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="bg-white rounded-2xl border p-5 h-24" />
        ))}
      </div>
      <div className="h-[92px] w-64 bg-white rounded-2xl border" />
      <div className="bg-white rounded-2xl border overflow-hidden">
        <div className="h-14 border-b" />
        <div className="h-10 bg-gray-100" />
        {Array.from({ length: RECENT_ROWS }).map((_, i) => (
          <div key={i} className="h-[45px] border-t border-gray-100" />
        ))}
      </div>
    </div>
  )
}
