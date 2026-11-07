'use client'
import { useCallback, useState } from 'react'
import { api, type Patient } from '@/lib/api'
import { useApiData } from '@/lib/useApiData'
import { useDebouncedSearch } from '@/lib/useDebouncedSearch'
import Modal from '@/components/ui/Modal'
import DataTable from '@/components/ui/DataTable'
import EmptyState from '@/components/ui/EmptyState'
import ErrorBanner from '@/components/ui/ErrorBanner'
import { Search, UserCircle, Phone, Calendar } from 'lucide-react'

const PAGE_SIZE = 20

export default function PatientsPage() {
  const [page, setPage] = useState(1)
  const { searchInput, setSearchInput, search } = useDebouncedSearch(setPage)
  const [selected, setSelected] = useState<Patient | null>(null)

  const fetchPatients = useCallback(
    (signal: AbortSignal) => api.patients(page, search, signal),
    [page, search],
  )
  const { data, error, loading } = useApiData(fetchPatients)
  const total = data?.total ?? 0

  return (
    <div className="space-y-6">
      <h1 className="title text-3xl">
        Patients <span className="text-ink-dim font-normal text-base">({total})</span>
      </h1>

      <div className="bg-panel-raised border border-edge rounded-md p-4 ">
        <div className="relative max-w-sm">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-dim" aria-hidden="true" />
          <input
            type="search"
            aria-label="Search patients by name or phone"
            placeholder="Search by name or phone…"
            value={searchInput}
            onChange={e => setSearchInput(e.target.value)}
            className="w-full pl-9 pr-3 py-2 text-sm border border-edge rounded-md focus:outline-none focus:ring-2 focus:ring-steel/40 focus:border-steel"
          />
        </div>
      </div>

      <ErrorBanner message={error} />

      <DataTable
        columns={[
          {
            header: 'Name', key: 'name',
            render: p => (
              <button type="button" onClick={() => setSelected(p)} className="font-medium text-ink text-left hover:underline">
                {p.full_name}
              </button>
            ),
          },
          { header: 'Phone', key: 'phone', render: p => <span className="text-ink-dim">{p.phone}</span> },
          {
            header: 'Date of Birth', key: 'dob',
            render: p => <span className="text-ink-dim text-xs">{p.date_of_birth ? new Date(p.date_of_birth).toLocaleDateString() : '—'}</span>,
          },
          {
            header: 'Emergency Contact', key: 'emergency',
            render: p => (
              <span className="text-ink-dim text-xs">
                {p.emergency_contact_name ? `${p.emergency_contact_name} (${p.emergency_contact_phone ?? '—'})` : '—'}
              </span>
            ),
          },
          { header: 'Joined', key: 'joined', render: p => <span className="text-ink-dim text-xs">{new Date(p.created_at).toLocaleDateString()}</span> },
          { header: 'Rides', key: 'rides', render: p => <span className="text-ink-dim font-medium">{p.total_rides ?? 0}</span> },
        ]}
        rows={data?.items ?? []}
        keyFn={p => p.id}
        loading={loading}
        emptySlot={
          <EmptyState
            icon={UserCircle}
            title="No patients found"
            description={search ? 'Try a different search term.' : 'Registered patients will appear here.'}
          />
        }
        page={page}
        totalPages={Math.ceil(total / PAGE_SIZE)}
        onPageChange={setPage}
      />

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
        <div className="w-14 h-14 rounded-full bg-steel/10 flex items-center justify-center text-steel font-bold text-xl">
          {p.full_name.charAt(0).toUpperCase()}
        </div>
        <div>
          <p className="text-lg font-bold text-ink">{p.full_name}</p>
          <div className="flex items-center gap-1 text-sm text-ink-dim">
            <Phone size={12} /> {p.phone}
          </div>
        </div>
        <div className="ml-auto text-center bg-panel-inset border border-edge rounded-md px-4 py-2">
          <p className="text-2xl font-bold text-steel">{p.total_rides ?? 0}</p>
          <p className="text-xs text-ink-dim font-medium">Total Rides</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        {p.date_of_birth && (
          <div className="bg-panel-inset rounded-md p-4">
            <div className="flex items-center gap-2 mb-1">
              <Calendar size={12} className="text-ink-dim" />
              <p className="text-xs text-ink-dim font-medium">Date of Birth</p>
            </div>
            <p className="font-semibold text-ink">{new Date(p.date_of_birth).toLocaleDateString()}</p>
          </div>
        )}
        <div className="bg-panel-inset rounded-md p-4">
          <p className="text-xs text-ink-dim font-medium mb-1">Member Since</p>
          <p className="font-semibold text-ink">{new Date(p.created_at).toLocaleDateString()}</p>
        </div>
      </div>

      {p.mobility_needs && (
        <div className="bg-lamp-amber/10 border border-lamp-amber/40 rounded-md p-4">
          <p className="text-xs text-lamp-amber font-semibold legend mb-1">Mobility Needs</p>
          <p className="text-sm text-amber-900">{p.mobility_needs}</p>
        </div>
      )}

      {p.emergency_contact_name && (
        <div className="border border-red-100 bg-lamp-red/10 rounded-md p-4">
          <p className="text-xs text-lamp-red font-semibold legend mb-2">Emergency Contact</p>
          <p className="font-semibold text-ink">{p.emergency_contact_name}</p>
          {p.emergency_contact_phone && (
            <div className="flex items-center gap-1 text-sm text-ink-dim mt-1">
              <Phone size={12} /> {p.emergency_contact_phone}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
