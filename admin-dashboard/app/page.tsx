'use client'
import { useEffect, useState } from 'react'
import { api, type DashboardSummary as Summary, type Ride } from '@/lib/api'
import StatCard from '@/components/ui/StatCard'
import StatusBadge from '@/components/ui/StatusBadge'
import { Car, AlertCircle, Activity, Users, Building2, Clock, TrendingUp, RefreshCw } from 'lucide-react'
import Link from 'next/link'

export default function DashboardPage() {
  const [data, setData] = useState<Summary | null>(null)
  const [recent, setRecent] = useState<Ride[]>([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)

  async function load() {
    try {
      const [summary, rides] = await Promise.all([
        api.summary(),
        api.rides(1),
      ])
      setData(summary)
      setRecent(rides.items.slice(0, 8))
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed to load')
    } finally {
      setLoading(false)
      setRefreshing(false)
    }
  }

  useEffect(() => {
    load()
    const interval = setInterval(load, 30_000)
    return () => clearInterval(interval)
  }, [])

  function handleRefresh() {
    setRefreshing(true)
    load()
  }

  if (loading) return <DashboardSkeleton />
  if (error) return (
    <div className="flex items-center gap-3 text-red-600 bg-red-50 border border-red-200 rounded-xl p-4">
      <AlertCircle size={18} />
      <span>{error}</span>
    </div>
  )
  if (!data) return null

  const cards = [
    { label: 'Total Rides', value: data.total_rides, icon: Car, color: 'blue' },
    { label: 'Emergency (24 h)', value: data.emergency_rides_24h, icon: AlertCircle, color: 'red' },
    { label: 'Active Rides', value: data.active_rides, icon: Activity, color: 'amber' },
    { label: 'Available Drivers', value: data.available_drivers, icon: Users, color: 'green' },
    { label: 'Total Drivers', value: data.total_drivers, icon: Users, color: 'gray' },
    { label: 'Hospitals Online', value: data.active_hospitals, icon: Building2, color: 'purple' },
  ]

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-blue-900">Dashboard</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            Last updated: {new Date(data.snapshot_at).toLocaleString()}
          </p>
        </div>
        <button
          onClick={handleRefresh}
          disabled={refreshing}
          className="flex items-center gap-2 text-sm bg-white border border-gray-200 hover:border-blue-300 px-4 py-2 rounded-xl shadow-sm transition disabled:opacity-50"
        >
          <RefreshCw size={14} className={refreshing ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        {cards.map(c => (
          <StatCard key={c.label} label={c.label} value={c.value} icon={c.icon} color={c.color} />
        ))}
      </div>

      {/* ETA card */}
      {data.avg_eta_seconds_24h !== null && (
        <div className="bg-white rounded-2xl border border-blue-100 p-5 shadow-sm inline-flex items-center gap-4">
          <div className="p-3 bg-cyan-50 border border-cyan-200 rounded-xl text-cyan-700">
            <Clock size={20} />
          </div>
          <div>
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wider">Avg ETA (24 h)</p>
            <p className="text-3xl font-bold text-gray-900">{Math.round(data.avg_eta_seconds_24h)}s</p>
          </div>
        </div>
      )}

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
                <td className="px-4 py-3 font-mono text-xs text-gray-400">{r.id.slice(0, 8)}…</td>
                <td className="px-4 py-3">
                  <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${r.ride_type === 'emergency' ? 'bg-red-100 text-red-700' : 'bg-blue-100 text-blue-700'}`}>
                    {r.ride_type}
                  </span>
                </td>
                <td className="px-4 py-3"><StatusBadge value={r.status} /></td>
                <td className="px-4 py-3 text-gray-600 text-xs max-w-[200px] truncate">
                  {r.pickup_address ?? `${r.pickup_lat.toFixed(4)}, ${r.pickup_lng.toFixed(4)}`}
                </td>
                <td className="px-4 py-3 text-gray-400 text-xs">{new Date(r.requested_at).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function DashboardSkeleton() {
  return (
    <div className="space-y-8 animate-pulse">
      <div className="h-8 bg-gray-200 rounded w-48" />
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="bg-white rounded-2xl border p-5 h-24" />
        ))}
      </div>
      <div className="bg-white rounded-2xl border h-64" />
    </div>
  )
}
