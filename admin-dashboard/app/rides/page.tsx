'use client'
import { useEffect, useState } from 'react'
import { api, type Ride } from '@/lib/api'

const STATUS_COLOURS: Record<string, string> = {
  pending: 'bg-yellow-100 text-yellow-800',
  driver_assigned: 'bg-blue-100 text-blue-800',
  driver_en_route: 'bg-indigo-100 text-indigo-800',
  patient_picked_up: 'bg-cyan-100 text-cyan-800',
  arrived_at_hospital: 'bg-purple-100 text-purple-800',
  completed: 'bg-green-100 text-green-800',
  cancelled: 'bg-red-100 text-red-800',
}

export default function RidesPage() {
  const [rides, setRides] = useState<Ride[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    setLoading(true)
    api.rides(page)
      .then(d => { setRides(d.items); setTotal(d.total) })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [page])

  const pages = Math.ceil(total / 20)

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Rides ({total})</h1>
      {error && <p className="text-red-600 mb-4">{error}</p>}
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 uppercase text-xs">
            <tr>
              {['ID', 'Type', 'Status', 'Pickup', 'Requested'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-400">Loading…</td></tr>
            ) : rides.map(r => (
              <tr key={r.id} className="hover:bg-gray-50">
                <td className="px-4 py-3 font-mono text-xs text-gray-500">{r.id.slice(0, 8)}…</td>
                <td className="px-4 py-3 capitalize">{r.ride_type}</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_COLOURS[r.status] ?? ''}`}>
                    {r.status.replace(/_/g, ' ')}
                  </span>
                </td>
                <td className="px-4 py-3 text-gray-600">
                  {r.pickup_address ?? `${r.pickup_lat.toFixed(4)}, ${r.pickup_lng.toFixed(4)}`}
                </td>
                <td className="px-4 py-3 text-gray-500 text-xs">
                  {new Date(r.requested_at).toLocaleString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {pages > 1 && (
        <div className="flex gap-2 mt-4">
          <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
            className="px-3 py-1 border rounded disabled:opacity-40">← Prev</button>
          <span className="px-3 py-1 text-sm text-gray-600">{page} / {pages}</span>
          <button onClick={() => setPage(p => Math.min(pages, p + 1))} disabled={page === pages}
            className="px-3 py-1 border rounded disabled:opacity-40">Next →</button>
        </div>
      )}
    </div>
  )
}
