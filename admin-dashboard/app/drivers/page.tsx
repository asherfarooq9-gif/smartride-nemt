'use client'
import { useEffect, useState, useCallback } from 'react'
import { api, type Driver } from '@/lib/api'
import StatusBadge from '@/components/ui/StatusBadge'
import Modal from '@/components/ui/Modal'
import LoadingRows from '@/components/ui/LoadingRows'
import { Search, Filter, Users, CheckCircle, XCircle, MapPin, Clock } from 'lucide-react'

const STATUS_OPTS = ['', 'available', 'busy', 'offline']

export default function DriversPage() {
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [verifiedFilter, setVerifiedFilter] = useState('')
  const [selected, setSelected] = useState<Driver | null>(null)
  const [verifying, setVerifying] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const d = await api.drivers(page, statusFilter, verifiedFilter, search)
      setDrivers(d.items)
      setTotal(d.total)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setLoading(false)
    }
  }, [page, statusFilter, verifiedFilter, search])

  useEffect(() => { load() }, [load])

  async function verify(id: string, verified: boolean) {
    setVerifying(id)
    try {
      const updated = await api.verifyDriver(id, verified)
      setDrivers(ds => ds.map(d => d.id === id ? updated : d))
      if (selected?.id === id) setSelected(updated)
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Error')
    } finally {
      setVerifying(null)
    }
  }

  const pages = Math.ceil(total / 20)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">
          Drivers <span className="text-gray-400 font-normal text-lg">({total})</span>
        </h1>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 bg-white border border-gray-100 rounded-2xl p-4 shadow-sm">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            placeholder="Search name, phone, plate…"
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1) }}
            className="w-full pl-9 pr-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
          />
        </div>
        <div className="flex items-center gap-2">
          <Filter size={14} className="text-gray-400" />
          <select
            value={statusFilter}
            onChange={e => { setStatusFilter(e.target.value); setPage(1) }}
            className="text-sm border border-gray-200 rounded-xl px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
          >
            <option value="">All Statuses</option>
            {STATUS_OPTS.filter(Boolean).map(s => <option key={s} value={s}>{s}</option>)}
          </select>
          <select
            value={verifiedFilter}
            onChange={e => { setVerifiedFilter(e.target.value); setPage(1) }}
            className="text-sm border border-gray-200 rounded-xl px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
          >
            <option value="">All Verification</option>
            <option value="true">Verified</option>
            <option value="false">Pending</option>
          </select>
        </div>
      </div>

      {error && <div className="text-red-600 bg-red-50 border border-red-200 rounded-xl p-4 text-sm">{error}</div>}

      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-xs uppercase border-b border-gray-100">
            <tr>
              {['Name', 'Phone', 'Vehicle', 'Status', 'Verified', 'Last Seen', 'Action'].map(h => (
                <th key={h} className="px-4 py-3 text-left font-medium">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {loading
              ? <LoadingRows cols={7} />
              : drivers.length === 0
                ? <tr><td colSpan={7} className="px-4 py-16 text-center text-gray-400">
                    <Users size={32} className="mx-auto mb-3 opacity-30" />
                    <p>No drivers found</p>
                  </td></tr>
                : drivers.map(d => (
                <tr
                  key={d.id}
                  className="hover:bg-blue-50/40 cursor-pointer transition-colors"
                  onClick={() => setSelected(d)}
                >
                  <td className="px-4 py-3 font-medium text-gray-900">{d.full_name}</td>
                  <td className="px-4 py-3 text-gray-500">{d.phone}</td>
                  <td className="px-4 py-3 text-gray-600 text-xs">{d.vehicle_plate} · {d.vehicle_type}</td>
                  <td className="px-4 py-3"><StatusBadge value={d.status} type="driver" /></td>
                  <td className="px-4 py-3">
                    {d.is_verified
                      ? <span className="flex items-center gap-1 text-green-600 text-xs font-medium"><CheckCircle size={12} /> Verified</span>
                      : <span className="flex items-center gap-1 text-amber-600 text-xs font-medium"><XCircle size={12} /> Pending</span>}
                  </td>
                  <td className="px-4 py-3 text-gray-400 text-xs">
                    {d.last_seen_at ? new Date(d.last_seen_at).toLocaleString() : '—'}
                  </td>
                  <td className="px-4 py-3" onClick={e => e.stopPropagation()}>
                    <button
                      onClick={() => verify(d.id, !d.is_verified)}
                      disabled={verifying === d.id}
                      className={`text-xs px-3 py-1.5 rounded-lg font-medium disabled:opacity-40 transition ${
                        d.is_verified
                          ? 'bg-red-50 text-red-700 hover:bg-red-100 border border-red-200'
                          : 'bg-blue-600 text-white hover:bg-blue-700'
                      }`}
                    >
                      {verifying === d.id ? '…' : d.is_verified ? 'Revoke' : 'Verify'}
                    </button>
                  </td>
                </tr>
              ))
            }
          </tbody>
        </table>
      </div>

      {pages > 1 && (
        <div className="flex items-center gap-2">
          <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
            className="px-4 py-2 border border-gray-200 rounded-xl text-sm disabled:opacity-40 hover:border-gray-300 transition">← Prev</button>
          <span className="px-3 py-2 text-sm text-gray-600">{page} / {pages}</span>
          <button onClick={() => setPage(p => Math.min(pages, p + 1))} disabled={page === pages}
            className="px-4 py-2 border border-gray-200 rounded-xl text-sm disabled:opacity-40 hover:border-gray-300 transition">Next →</button>
        </div>
      )}

      <Modal open={selected !== null} onClose={() => setSelected(null)} title="Driver Details" width="lg">
        {selected && (
          <DriverDetail
            driver={selected}
            onVerify={(v) => verify(selected.id, v)}
            verifying={verifying === selected.id}
          />
        )}
      </Modal>
    </div>
  )
}

function DriverDetail({ driver: d, onVerify, verifying }: { driver: Driver; onVerify: (v: boolean) => void; verifying: boolean }) {
  return (
    <div className="space-y-5">
      {/* Avatar + name */}
      <div className="flex items-center gap-4">
        <div className="w-14 h-14 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold text-xl">
          {d.full_name.charAt(0).toUpperCase()}
        </div>
        <div>
          <p className="text-lg font-bold text-gray-900">{d.full_name}</p>
          <p className="text-sm text-gray-500">{d.phone}</p>
        </div>
        <div className="ml-auto flex flex-col items-end gap-2">
          <StatusBadge value={d.status} type="driver" size="md" />
          {d.is_verified
            ? <span className="flex items-center gap-1 text-green-600 text-xs font-medium"><CheckCircle size={12} /> Verified</span>
            : <span className="flex items-center gap-1 text-amber-600 text-xs font-medium"><XCircle size={12} /> Pending</span>}
        </div>
      </div>

      {/* Details */}
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-gray-50 rounded-xl p-4">
          <p className="text-xs text-gray-400 font-medium mb-1">License No.</p>
          <p className="font-semibold text-gray-900">{d.license_no}</p>
        </div>
        <div className="bg-gray-50 rounded-xl p-4">
          <p className="text-xs text-gray-400 font-medium mb-1">Vehicle Plate</p>
          <p className="font-semibold text-gray-900">{d.vehicle_plate}</p>
        </div>
        <div className="bg-gray-50 rounded-xl p-4">
          <p className="text-xs text-gray-400 font-medium mb-1">Vehicle Type</p>
          <p className="font-semibold text-gray-900 capitalize">{d.vehicle_type}</p>
        </div>
        <div className="bg-gray-50 rounded-xl p-4">
          <p className="text-xs text-gray-400 font-medium mb-1">Member Since</p>
          <p className="font-semibold text-gray-900">{new Date(d.created_at).toLocaleDateString()}</p>
        </div>
      </div>

      {/* Location */}
      {d.current_lat && (
        <div className="flex items-center gap-3 bg-green-50 border border-green-200 rounded-xl p-3 text-sm text-green-800">
          <MapPin size={14} />
          <span>Last location: {d.current_lat.toFixed(4)}, {d.current_lng?.toFixed(4)}</span>
        </div>
      )}
      {d.last_seen_at && (
        <div className="flex items-center gap-3 bg-gray-50 rounded-xl p-3 text-xs text-gray-500">
          <Clock size={12} />
          Last seen: {new Date(d.last_seen_at).toLocaleString()}
        </div>
      )}

      {/* Actions */}
      <div className="flex gap-3 pt-2 border-t border-gray-100">
        <button
          onClick={() => onVerify(!d.is_verified)}
          disabled={verifying}
          className={`flex-1 py-2.5 rounded-xl text-sm font-medium transition disabled:opacity-40 ${
            d.is_verified
              ? 'bg-red-50 text-red-700 hover:bg-red-100 border border-red-200'
              : 'bg-blue-600 text-white hover:bg-blue-700'
          }`}
        >
          {verifying ? '…' : d.is_verified ? 'Revoke Verification' : 'Verify Driver'}
        </button>
      </div>
    </div>
  )
}
