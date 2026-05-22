'use client'
import { useEffect, useState } from 'react'
import { api, type DashboardSummary as Summary } from '@/lib/api'

export default function DashboardPage() {
  const [data, setData] = useState<Summary | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    api.summary()
      .then(d => setData(d))
      .catch(e => setError(e.message))
  }, [])

  if (error) return <p className="text-red-600">{error}</p>
  if (!data) return <p className="text-gray-400">Loading…</p>

  const cards = [
    { label: 'Total Rides', value: data.total_rides, color: 'blue' },
    { label: 'Emergency (24 h)', value: data.emergency_rides_24h, color: 'red' },
    { label: 'Active Rides', value: data.active_rides, color: 'yellow' },
    { label: 'Available Drivers', value: data.available_drivers, color: 'green' },
    { label: 'Total Drivers', value: data.total_drivers, color: 'gray' },
    { label: 'Hospitals Online', value: data.active_hospitals, color: 'purple' },
  ]

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Dashboard</h1>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-8">
        {cards.map(c => <StatCard key={c.label} {...c} />)}
      </div>
      {data.avg_eta_seconds_24h !== null && (
        <div className="bg-white rounded-xl shadow-sm p-5 inline-block">
          <p className="text-sm text-gray-500 uppercase tracking-wide">Avg ETA (24 h)</p>
          <p className="text-3xl font-bold mt-1">{Math.round(data.avg_eta_seconds_24h)} s</p>
        </div>
      )}
      <p className="text-xs text-gray-400 mt-6">
        Snapshot: {new Date(data.snapshot_at).toLocaleString()}
      </p>
    </div>
  )
}

const COLORS: Record<string, string> = {
  blue: 'border-blue-500 bg-blue-50',
  red: 'border-red-500 bg-red-50',
  yellow: 'border-yellow-500 bg-yellow-50',
  green: 'border-green-500 bg-green-50',
  gray: 'border-gray-400 bg-gray-50',
  purple: 'border-purple-500 bg-purple-50',
}

function StatCard({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className={`rounded-lg border-l-4 p-5 shadow-sm ${COLORS[color] ?? ''}`}>
      <p className="text-sm text-gray-500 uppercase tracking-wide">{label}</p>
      <p className="text-3xl font-bold mt-1">{value}</p>
    </div>
  )
}
