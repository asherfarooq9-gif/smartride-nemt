'use client'
import { useEffect, useState, useCallback } from 'react'
import { api, type Ride, type RideDetail } from '@/lib/api'
import StatusBadge from '@/components/ui/StatusBadge'
import Modal from '@/components/ui/Modal'
import LoadingRows from '@/components/ui/LoadingRows'
import { Search, Filter, Download, Car, MapPin, Clock, User, Truck, Building2 } from 'lucide-react'

const STATUSES = ['', 'pending', 'driver_assigned', 'driver_en_route', 'patient_picked_up', 'arrived_at_hospital', 'completed', 'cancelled']
const TYPES = ['', 'emergency', 'scheduled']

function downloadCsv(rides: Ride[]) {
  const header = 'ID,Type,Status,Pickup,Requested,Completed\n'
  const rows = rides.map(r =>
    `${r.id},${r.ride_type},${r.status},"${r.pickup_address ?? `${r.pickup_lat},${r.pickup_lng}`}",${r.requested_at},${r.completed_at ?? ''}`
  ).join('\n')
  const blob = new Blob([header + rows], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a'); a.href = url; a.download = 'rides.csv'; a.click()
  URL.revokeObjectURL(url)
}

export default function RidesPage() {
  const [rides, setRides] = useState<Ride[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [typeFilter, setTypeFilter] = useState('')
  const [selected, setSelected] = useState<RideDetail | null>(null)
  const [modalLoading, setModalLoading] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const d = await api.rides(page, statusFilter, typeFilter, search)
      setRides(d.items)
      setTotal(d.total)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setLoading(false)
    }
  }, [page, statusFilter, typeFilter, search])

  useEffect(() => { load() }, [load])

  async function openDetail(id: string) {
    setModalLoading(true)
    setSelected(null)
    try {
      const d = await api.rideDetail(id)
      setSelected(d)
    } catch {
      setSelected(null)
    } finally {
      setModalLoading(false)
    }
  }

  const pages = Math.ceil(total / 20)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Rides <span className="text-gray-400 font-normal text-lg">({total})</span></h1>
        <button
          onClick={() => downloadCsv(rides)}
          className="flex items-center gap-2 text-sm bg-white border border-gray-200 hover:border-gray-300 px-4 py-2 rounded-xl shadow-sm transition"
        >
          <Download size={14} />
          Export CSV
        </button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 bg-white border border-gray-100 rounded-2xl p-4 shadow-sm">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            placeholder="Search pickup address…"
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
            className="text-sm border border-gray-200 rounded-xl px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
          >
            <option value="">All Statuses</option>
            {STATUSES.filter(Boolean).map(s => (
              <option key={s} value={s}>{s.replace(/_/g, ' ')}</option>
            ))}
          </select>
          <select
            value={typeFilter}
            onChange={e => { setTypeFilter(e.target.value); setPage(1) }}
            className="text-sm border border-gray-200 rounded-xl px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
          >
            <option value="">All Types</option>
            {TYPES.filter(Boolean).map(t => (
              <option key={t} value={t}>{t}</option>
            ))}
          </select>
        </div>
      </div>

      {error && (
        <div className="text-red-600 bg-red-50 border border-red-200 rounded-xl p-4 text-sm">{error}</div>
      )}

      {/* Table */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 text-xs uppercase border-b border-gray-100">
            <tr>
              {['ID', 'Type', 'Status', 'Pickup', 'Requested', 'Completed'].map(h => (
                <th key={h} className="px-4 py-3 text-left font-medium">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {loading
              ? <LoadingRows cols={6} />
              : rides.length === 0
                ? <tr><td colSpan={6} className="px-4 py-16 text-center text-gray-400">
                    <Car size={32} className="mx-auto mb-3 opacity-30" />
                    <p>No rides found</p>
                  </td></tr>
                : rides.map(r => (
                <tr
                  key={r.id}
                  className="hover:bg-blue-50/40 cursor-pointer transition-colors"
                  onClick={() => openDetail(r.id)}
                >
                  <td className="px-4 py-3 font-mono text-xs text-gray-400">{r.id.slice(0, 8)}…</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${r.ride_type === 'emergency' ? 'bg-red-100 text-red-700' : 'bg-blue-100 text-blue-700'}`}>
                      {r.ride_type}
                    </span>
                  </td>
                  <td className="px-4 py-3"><StatusBadge value={r.status} /></td>
                  <td className="px-4 py-3 text-gray-600 max-w-[200px] truncate text-xs">
                    {r.pickup_address ?? `${r.pickup_lat.toFixed(4)}, ${r.pickup_lng.toFixed(4)}`}
                  </td>
                  <td className="px-4 py-3 text-gray-400 text-xs">{new Date(r.requested_at).toLocaleString()}</td>
                  <td className="px-4 py-3 text-gray-400 text-xs">{r.completed_at ? new Date(r.completed_at).toLocaleString() : '—'}</td>
                </tr>
              ))
            }
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {pages > 1 && (
        <div className="flex items-center gap-2">
          <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
            className="px-4 py-2 border border-gray-200 rounded-xl text-sm disabled:opacity-40 hover:border-gray-300 transition">← Prev</button>
          <span className="px-3 py-2 text-sm text-gray-600">{page} / {pages}</span>
          <button onClick={() => setPage(p => Math.min(pages, p + 1))} disabled={page === pages}
            className="px-4 py-2 border border-gray-200 rounded-xl text-sm disabled:opacity-40 hover:border-gray-300 transition">Next →</button>
        </div>
      )}

      {/* Detail Modal */}
      <Modal open={selected !== null || modalLoading} onClose={() => setSelected(null)} title="Ride Details" width="xl">
        {modalLoading && (
          <div className="space-y-3 animate-pulse">
            {Array.from({ length: 6 }).map((_, i) => <div key={i} className="h-10 bg-gray-100 rounded-xl" />)}
          </div>
        )}
        {selected && <RideDetailView ride={selected} onClose={() => setSelected(null)} onUpdate={load} />}
      </Modal>
    </div>
  )
}

function RideDetailView({ ride, onClose, onUpdate }: { ride: RideDetail; onClose: () => void; onUpdate: () => void }) {
  const [cancelling, setCancelling] = useState(false)

  const canCancel = ride.status === 'pending' || ride.status === 'driver_assigned'

  async function cancelRide() {
    if (!confirm('Cancel this ride?')) return
    setCancelling(true)
    try {
      await api.cancelRide(ride.id)
      onUpdate()
      onClose()
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Error')
    } finally {
      setCancelling(false)
    }
  }

  return (
    <div className="space-y-5">
      {/* Status + Type */}
      <div className="flex items-center gap-3 flex-wrap">
        <StatusBadge value={ride.status} size="md" />
        <span className={`text-sm font-medium px-3 py-1 rounded-full border ${ride.ride_type === 'emergency' ? 'bg-red-50 border-red-200 text-red-700' : 'bg-blue-50 border-blue-200 text-blue-700'}`}>
          {ride.ride_type}
        </span>
        {canCancel && (
          <button
            onClick={cancelRide}
            disabled={cancelling}
            className="ml-auto text-sm bg-red-600 hover:bg-red-700 text-white px-4 py-1.5 rounded-xl disabled:opacity-40 transition"
          >
            {cancelling ? 'Cancelling…' : 'Cancel Ride'}
          </button>
        )}
      </div>

      {/* Info grid */}
      <div className="grid grid-cols-2 gap-4">
        <InfoBlock icon={MapPin} label="Pickup">
          {ride.pickup_address ?? `${ride.pickup_lat.toFixed(5)}, ${ride.pickup_lng.toFixed(5)}`}
        </InfoBlock>
        <InfoBlock icon={Clock} label="Requested">
          {new Date(ride.requested_at).toLocaleString()}
        </InfoBlock>
        {ride.driver_assigned_at && (
          <InfoBlock icon={Clock} label="Driver Assigned">
            {new Date(ride.driver_assigned_at).toLocaleString()}
          </InfoBlock>
        )}
        {ride.completed_at && (
          <InfoBlock icon={Clock} label="Completed">
            {new Date(ride.completed_at).toLocaleString()}
          </InfoBlock>
        )}
        {ride.estimated_fare_pkr && (
          <InfoBlock icon={Car} label="Estimated Fare">PKR {ride.estimated_fare_pkr}</InfoBlock>
        )}
        {ride.final_fare_pkr && (
          <InfoBlock icon={Car} label="Final Fare">PKR {ride.final_fare_pkr}</InfoBlock>
        )}
      </div>

      {/* Patient */}
      {ride.patient && (
        <div className="border border-gray-100 rounded-xl p-4 space-y-1">
          <div className="flex items-center gap-2 mb-2">
            <User size={14} className="text-blue-600" />
            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Patient</span>
          </div>
          <p className="font-medium text-gray-900">{ride.patient.full_name}</p>
          <p className="text-sm text-gray-500">{ride.patient.phone}</p>
          {ride.patient.mobility_needs && (
            <p className="text-xs text-amber-700 bg-amber-50 rounded px-2 py-1 mt-1">{ride.patient.mobility_needs}</p>
          )}
        </div>
      )}

      {/* Driver */}
      {ride.driver && (
        <div className="border border-gray-100 rounded-xl p-4 space-y-1">
          <div className="flex items-center gap-2 mb-2">
            <Truck size={14} className="text-green-600" />
            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Driver</span>
          </div>
          <p className="font-medium text-gray-900">{ride.driver.full_name}</p>
          <p className="text-sm text-gray-500">{ride.driver.phone} · {ride.driver.vehicle_plate} ({ride.driver.vehicle_type})</p>
        </div>
      )}

      {/* Hospital */}
      {ride.hospital && (
        <div className="border border-gray-100 rounded-xl p-4 space-y-1">
          <div className="flex items-center gap-2 mb-2">
            <Building2 size={14} className="text-purple-600" />
            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">Hospital</span>
          </div>
          <p className="font-medium text-gray-900">{ride.hospital.name}</p>
          <p className="text-sm text-gray-500">{ride.hospital.address}, {ride.hospital.city}</p>
        </div>
      )}

      {/* Triage */}
      {ride.triage && (
        <div className="border border-gray-100 rounded-xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">AI Triage</span>
          </div>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div><p className="text-xs text-gray-400">Specialty</p><p className="font-medium capitalize">{ride.triage.predicted_specialty.replace(/_/g, ' ')}</p></div>
            <div><p className="text-xs text-gray-400">Severity</p><p className="font-medium">Level {ride.triage.severity_level}</p></div>
            <div><p className="text-xs text-gray-400">Confidence</p><p className="font-medium">{(Number(ride.triage.confidence_score) * 100).toFixed(1)}%</p></div>
          </div>
          <p className="mt-2 text-xs text-gray-600 bg-gray-50 rounded-lg p-2">{ride.triage.symptom_text}</p>
        </div>
      )}
    </div>
  )
}

function InfoBlock({ icon: Icon, label, children }: { icon: React.ElementType; label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3">
      <div className="p-2 bg-gray-50 rounded-lg shrink-0"><Icon size={13} className="text-gray-500" /></div>
      <div>
        <p className="text-xs text-gray-400 font-medium">{label}</p>
        <p className="text-sm text-gray-800 font-medium mt-0.5">{children}</p>
      </div>
    </div>
  )
}
