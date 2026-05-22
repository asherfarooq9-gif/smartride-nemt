'use client'
import { useEffect, useState } from 'react'
import { api, type Driver } from '@/lib/api'

const STATUS_COLOURS: Record<string, string> = {
  available: 'bg-green-100 text-green-800',
  busy: 'bg-yellow-100 text-yellow-800',
  offline: 'bg-gray-100 text-gray-600',
}

export default function DriversPage() {
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [verifying, setVerifying] = useState<string | null>(null)

  async function loadPage(p: number) {
    setLoading(true)
    try {
      const d = await api.drivers(p)
      setDrivers(d.items)
      setTotal(d.total)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { loadPage(page) }, [page])

  async function verify(id: string) {
    setVerifying(id)
    try {
      const updated = await api.verifyDriver(id)
      setDrivers(ds => ds.map(d => d.id === id ? updated : d))
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Error verifying driver')
    } finally {
      setVerifying(null)
    }
  }

  const pages = Math.ceil(total / 20)

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Drivers ({total})</h1>
      {error && <p className="text-red-600 mb-4">{error}</p>}
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 uppercase text-xs">
            <tr>
              {['Name', 'Phone', 'Vehicle', 'Status', 'Verified', 'Action'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">Loading…</td></tr>
            ) : drivers.map(d => (
              <tr key={d.id} className="hover:bg-gray-50">
                <td className="px-4 py-3 font-medium">{d.full_name}</td>
                <td className="px-4 py-3 text-gray-600">{d.phone}</td>
                <td className="px-4 py-3 text-gray-600">{d.vehicle_plate} ({d.vehicle_type})</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_COLOURS[d.status] ?? ''}`}>
                    {d.status}
                  </span>
                </td>
                <td className="px-4 py-3">
                  {d.is_verified
                    ? <span className="text-green-600 font-medium">✓ Verified</span>
                    : <span className="text-gray-400">Pending</span>}
                </td>
                <td className="px-4 py-3">
                  {!d.is_verified && (
                    <button
                      onClick={() => verify(d.id)}
                      disabled={verifying === d.id}
                      className="text-xs bg-blue-700 hover:bg-blue-800 text-white px-3 py-1 rounded disabled:opacity-40"
                    >
                      {verifying === d.id ? '…' : 'Verify'}
                    </button>
                  )}
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
