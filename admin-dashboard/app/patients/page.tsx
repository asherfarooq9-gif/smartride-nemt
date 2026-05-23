'use client'
import { useEffect, useState, useCallback } from 'react'
import { api, type Patient } from '@/lib/api'
import Modal from '@/components/ui/Modal'
import LoadingRows from '@/components/ui/LoadingRows'
import { Search, UserCircle, Phone, Calendar, AlertCircle } from 'lucide-react'

export default function PatientsPage() {
  const [patients, setPatients] = useState<Patient[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<Patient | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const d = await api.patients(page, search)
      setPatients(d.items)
      setTotal(d.total)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error loading patients')
    } finally {
      setLoading(false)
    }
  }, [page, search])

  useEffect(() => { load() }, [load])

  const pages = Math.ceil(total / 20)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-blue-900">
          Patients <span className="text-blue-300 font-normal text-lg">({total})</span>
        </h1>
      </div>

      {/* Search */}
      <div className="bg-white border border-blue-100 rounded-2xl p-4 shadow-sm">
        <div className="relative max-w-sm">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            placeholder="Search by name or phone…"
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1) }}
            className="w-full pl-9 pr-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
          />
        </div>
      </div>

      {error && (
        <div className="flex items-center gap-3 text-red-600 bg-red-50 border border-red-200 rounded-xl p-4 text-sm">
          <AlertCircle size={16} /> {error}
        </div>
      )}

      <div className="bg-white rounded-2xl border border-blue-100 shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-blue-50 text-blue-600 text-xs uppercase border-b border-blue-100">
            <tr>
              {['Name', 'Phone', 'Date of Birth', 'Emergency Contact', 'Joined', 'Rides'].map(h => (
                <th key={h} className="px-4 py-3 text-left font-medium">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-blue-50">
            {loading
              ? <LoadingRows cols={6} />
              : patients.length === 0
                ? <tr><td colSpan={6} className="px-4 py-16 text-center text-gray-400">
                    <UserCircle size={32} className="mx-auto mb-3 opacity-30" />
                    <p>No patients found</p>
                  </td></tr>
                : patients.map(p => (
                <tr key={p.id} className="hover:bg-blue-50/40 cursor-pointer transition-colors" onClick={() => setSelected(p)}>
                  <td className="px-4 py-3 font-medium text-gray-900">{p.full_name}</td>
                  <td className="px-4 py-3 text-gray-500">{p.phone}</td>
                  <td className="px-4 py-3 text-gray-500 text-xs">
                    {p.date_of_birth ? new Date(p.date_of_birth).toLocaleDateString() : '—'}
                  </td>
                  <td className="px-4 py-3 text-gray-500 text-xs">
                    {p.emergency_contact_name
                      ? `${p.emergency_contact_name} (${p.emergency_contact_phone ?? '—'})`
                      : '—'}
                  </td>
                  <td className="px-4 py-3 text-gray-400 text-xs">{new Date(p.created_at).toLocaleDateString()}</td>
                  <td className="px-4 py-3 text-gray-600 font-medium">{p.total_rides ?? 0}</td>
                </tr>
              ))
            }
          </tbody>
        </table>
      </div>

      {pages > 1 && (
        <div className="flex items-center gap-2">
          <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
            className="px-4 py-2 border border-blue-200 rounded-xl text-sm disabled:opacity-40 hover:border-blue-400 transition">← Prev</button>
          <span className="px-3 py-2 text-sm text-blue-700">{page} / {pages}</span>
          <button onClick={() => setPage(p => Math.min(pages, p + 1))} disabled={page === pages}
            className="px-4 py-2 border border-blue-200 rounded-xl text-sm disabled:opacity-40 hover:border-blue-400 transition">Next →</button>
        </div>
      )}

      <Modal open={selected !== null} onClose={() => setSelected(null)} title="Patient Profile" width="lg">
        {selected && <PatientDetail patient={selected} />}
      </Modal>
    </div>
  )
}

function PatientDetail({ patient: p }: { patient: Patient }) {
  return (
    <div className="space-y-5">
      {/* Avatar */}
      <div className="flex items-center gap-4">
        <div className="w-14 h-14 rounded-full bg-purple-100 flex items-center justify-center text-purple-700 font-bold text-xl">
          {p.full_name.charAt(0).toUpperCase()}
        </div>
        <div>
          <p className="text-lg font-bold text-gray-900">{p.full_name}</p>
          <div className="flex items-center gap-1 text-sm text-gray-500">
            <Phone size={12} /> {p.phone}
          </div>
        </div>
        <div className="ml-auto text-center bg-blue-50 border border-blue-200 rounded-xl px-4 py-2">
          <p className="text-2xl font-bold text-blue-700">{p.total_rides ?? 0}</p>
          <p className="text-xs text-blue-500 font-medium">Total Rides</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        {p.date_of_birth && (
          <div className="bg-blue-50 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-1">
              <Calendar size={12} className="text-gray-400" />
              <p className="text-xs text-gray-400 font-medium">Date of Birth</p>
            </div>
            <p className="font-semibold text-gray-900">{new Date(p.date_of_birth).toLocaleDateString()}</p>
          </div>
        )}
        <div className="bg-gray-50 rounded-xl p-4">
          <p className="text-xs text-gray-400 font-medium mb-1">Member Since</p>
          <p className="font-semibold text-gray-900">{new Date(p.created_at).toLocaleDateString()}</p>
        </div>
      </div>

      {p.mobility_needs && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <p className="text-xs text-amber-700 font-semibold uppercase tracking-wider mb-1">Mobility Needs</p>
          <p className="text-sm text-amber-900">{p.mobility_needs}</p>
        </div>
      )}

      {p.emergency_contact_name && (
        <div className="border border-red-100 bg-red-50 rounded-xl p-4">
          <p className="text-xs text-red-700 font-semibold uppercase tracking-wider mb-2">Emergency Contact</p>
          <p className="font-semibold text-gray-900">{p.emergency_contact_name}</p>
          {p.emergency_contact_phone && (
            <div className="flex items-center gap-1 text-sm text-gray-600 mt-1">
              <Phone size={12} /> {p.emergency_contact_phone}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
