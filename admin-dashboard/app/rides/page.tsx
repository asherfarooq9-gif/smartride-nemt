'use client'
import { useCallback, useState } from 'react'
import { api, type Ride, type RideDetail } from '@/lib/api'
import { downloadCsv, toCsv } from '@/lib/csv'
import { useApiData } from '@/lib/useApiData'
import { useDebouncedSearch } from '@/lib/useDebouncedSearch'
import StatusBadge from '@/components/ui/StatusBadge'
import Modal from '@/components/ui/Modal'
import DataTable from '@/components/ui/DataTable'
import EmptyState from '@/components/ui/EmptyState'
import ErrorBanner from '@/components/ui/ErrorBanner'
import RideDetailView from './RideDetailView'
import { Search, Filter, Download, Car } from 'lucide-react'

const STATUSES = ['pending', 'driver_assigned', 'driver_en_route', 'patient_picked_up', 'arrived_at_hospital', 'completed', 'cancelled']
const TYPES = ['emergency', 'scheduled']
const PAGE_SIZE = 20

function exportRides(rides: Ride[]) {
  const rows = rides.map(r => [
    r.id, r.ride_type, r.status,
    r.pickup_address ?? `${r.pickup_lat},${r.pickup_lng}`,
    r.requested_at, r.completed_at,
  ])
  downloadCsv('rides.csv', toCsv(['ID', 'Type', 'Status', 'Pickup', 'Requested', 'Completed'], rows))
}

export default function RidesPage() {
  const [page, setPage] = useState(1)
  const { searchInput, setSearchInput, search } = useDebouncedSearch(setPage)
  const [statusFilter, setStatusFilter] = useState('')
  const [typeFilter, setTypeFilter] = useState('')
  const [detailId, setDetailId] = useState<string | null>(null)

  const fetchRides = useCallback(
    (signal: AbortSignal) => api.rides(page, statusFilter, typeFilter, search, signal),
    [page, statusFilter, typeFilter, search],
  )
  const { data, error, loading, reload } = useApiData(fetchRides)

  const fetchDetail = useCallback(
    (signal: AbortSignal): Promise<RideDetail | null> =>
      detailId ? api.rideDetail(detailId, signal) : Promise.resolve(null),
    [detailId],
  )
  const { data: detail, error: detailError, loading: detailLoading, reload: reloadDetail } = useApiData(fetchDetail)

  const rides = data?.items ?? []
  const total = data?.total ?? 0

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-blue-900">Rides <span className="text-blue-600 font-normal text-lg">({total})</span></h1>
        <button
          type="button"
          onClick={() => exportRides(rides)}
          className="flex items-center gap-2 text-sm bg-white border border-gray-200 hover:border-gray-300 px-4 py-2 rounded-xl shadow-sm transition"
        >
          <Download size={14} aria-hidden="true" />
          Export CSV
        </button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 bg-white border border-blue-100 rounded-2xl p-4 shadow-sm">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" aria-hidden="true" />
          <input
            type="search"
            aria-label="Search rides by pickup address"
            placeholder="Search pickup address…"
            value={searchInput}
            onChange={e => setSearchInput(e.target.value)}
            className="w-full pl-9 pr-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
          />
        </div>
        <div className="flex items-center gap-2">
          <Filter size={14} className="text-gray-400" aria-hidden="true" />
          <select
            aria-label="Filter by status"
            value={statusFilter}
            onChange={e => { setStatusFilter(e.target.value); setPage(1) }}
            className="text-sm border border-gray-200 rounded-xl px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
          >
            <option value="">All Statuses</option>
            {STATUSES.map(s => (
              <option key={s} value={s}>{s.replace(/_/g, ' ')}</option>
            ))}
          </select>
          <select
            aria-label="Filter by ride type"
            value={typeFilter}
            onChange={e => { setTypeFilter(e.target.value); setPage(1) }}
            className="text-sm border border-gray-200 rounded-xl px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
          >
            <option value="">All Types</option>
            {TYPES.map(t => (
              <option key={t} value={t}>{t}</option>
            ))}
          </select>
        </div>
      </div>

      <ErrorBanner message={error} />

      {/* Table */}
      <DataTable
        columns={[
          {
            header: 'Type', key: 'ride_type',
            render: r => (
              <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${r.ride_type === 'emergency' ? 'bg-red-100 text-red-700' : 'bg-blue-100 text-blue-700'}`}>
                {r.ride_type}
              </span>
            )
          },
          { header: 'Status', key: 'status', render: r => <StatusBadge value={r.status} /> },
          {
            header: 'Pickup', key: 'pickup',
            render: r => <span className="text-gray-600 text-xs">{r.pickup_address ?? `${r.pickup_lat?.toFixed(4)}, ${r.pickup_lng?.toFixed(4)}`}</span>
          },
          {
            header: 'Requested', key: 'requested_at',
            render: r => <span className="text-gray-500 text-xs">{new Date(r.requested_at).toLocaleString()}</span>
          },
          {
            header: 'Actions', key: 'actions', hideHeader: true,
            render: r => (
              <button type="button" onClick={() => setDetailId(r.id)} className="text-blue-700 hover:underline text-xs">
                Detail<span className="sr-only"> for ride {r.id.slice(0, 8)}</span>
              </button>
            )
          },
        ]}
        rows={rides}
        keyFn={r => r.id}
        loading={loading}
        emptySlot={
          <EmptyState
            icon={Car}
            title="No rides found"
            description={search || statusFilter || typeFilter ? 'Try adjusting your filters.' : 'Rides will appear here once patients book.'}
          />
        }
        page={page}
        totalPages={Math.ceil(total / PAGE_SIZE)}
        onPageChange={setPage}
      />

      <Modal open={detailId !== null} onClose={() => setDetailId(null)} title="Ride Details" width="xl">
        {detailLoading && (
          <div className="space-y-3 animate-pulse" role="status" aria-label="Loading ride details">
            {Array.from({ length: 6 }).map((_, i) => <div key={i} className="h-10 bg-gray-100 rounded-xl" />)}
          </div>
        )}
        <ErrorBanner message={detailError} />
        {detailError && (
          <button type="button" onClick={reloadDetail} className="mt-3 text-sm text-blue-700 hover:underline">
            Try again
          </button>
        )}
        {!detailLoading && detail && (
          <RideDetailView ride={detail} onCancelled={() => { setDetailId(null); reload() }} />
        )}
      </Modal>
    </div>
  )
}
