'use client'
import { useCallback, useState } from 'react'
import { api, errorMessage, type Driver } from '@/lib/api'
import { useApiData } from '@/lib/useApiData'
import { useDebouncedSearch } from '@/lib/useDebouncedSearch'
import StatusBadge from '@/components/ui/StatusBadge'
import Modal from '@/components/ui/Modal'
import DataTable from '@/components/ui/DataTable'
import EmptyState from '@/components/ui/EmptyState'
import ErrorBanner from '@/components/ui/ErrorBanner'
import { Search, Filter, Users, CheckCircle, XCircle, MapPin, Clock } from 'lucide-react'
import { useInFlight } from '@/lib/useInFlight'
import ConfirmDialog from '@/components/ui/ConfirmDialog'

const STATUS_OPTS = ['available', 'busy', 'offline']
const PAGE_SIZE = 20

function VerifiedBadge({ isVerified }: { isVerified: boolean }) {
  return isVerified
    ? <span className="flex items-center gap-1 text-lamp-green text-xs font-medium"><CheckCircle size={12} /> Verified</span>
    : <span className="flex items-center gap-1 text-lamp-amber text-xs font-medium"><XCircle size={12} /> Pending</span>
}

export default function DriversPage() {
  const [page, setPage] = useState(1)
  const { searchInput, setSearchInput, search } = useDebouncedSearch(setPage)
  const [statusFilter, setStatusFilter] = useState('')
  const [verifiedFilter, setVerifiedFilter] = useState('')
  const [selected, setSelected] = useState<Driver | null>(null)
  const { isBusy: isVerifying, run: runVerify } = useInFlight()
  const [revoking, setRevoking] = useState<Driver | null>(null)
  const [verifyError, setVerifyError] = useState('')

  const fetchDrivers = useCallback(
    (signal: AbortSignal) => api.drivers(page, statusFilter, verifiedFilter, search, signal),
    [page, statusFilter, verifiedFilter, search],
  )
  const { data, error, loading, reload } = useApiData(fetchDrivers)
  const total = data?.total ?? 0

  async function verify(id: string, verified: boolean) {
    setVerifyError('')
    await runVerify(id, async () => {
      try {
        const updated = await api.verifyDriver(id, verified)
        if (selected?.id === id) setSelected(updated)
        reload()
      } catch (e: unknown) {
        setVerifyError(errorMessage(e, 'Error updating driver'))
      }
    })
  }

  const hasFilters = Boolean(search || statusFilter || verifiedFilter)

  return (
    <div className="space-y-6">
      <h1 className="title text-3xl">
        Drivers <span className="text-ink-dim font-normal text-base">({total})</span>
      </h1>

      <div className="flex flex-wrap gap-3 bg-panel-raised border border-edge rounded-md p-4 ">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-dim" aria-hidden="true" />
          <input
            type="search"
            aria-label="Search drivers by name, phone or plate"
            placeholder="Search name, phone, plate…"
            value={searchInput}
            onChange={e => setSearchInput(e.target.value)}
            className="w-full pl-9 pr-3 py-2 text-sm border border-edge rounded-md focus:outline-none focus:ring-2 focus:ring-steel/40 focus:border-steel"
          />
        </div>
        <div className="flex items-center gap-2">
          <Filter size={14} className="text-ink-dim" aria-hidden="true" />
          <select
            aria-label="Filter by status"
            value={statusFilter}
            onChange={e => { setStatusFilter(e.target.value); setPage(1) }}
            className="text-sm border border-edge rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-steel/40"
          >
            <option value="">All Statuses</option>
            {STATUS_OPTS.map(s => <option key={s} value={s}>{s}</option>)}
          </select>
          <select
            aria-label="Filter by verification"
            value={verifiedFilter}
            onChange={e => { setVerifiedFilter(e.target.value); setPage(1) }}
            className="text-sm border border-edge rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-steel/40"
          >
            <option value="">All Verification</option>
            <option value="true">Verified</option>
            <option value="false">Pending</option>
          </select>
        </div>
      </div>

      <ErrorBanner message={error} />
      <ErrorBanner message={verifyError} />

      <DataTable
        columns={[
          {
            header: 'Name', key: 'name',
            render: d => (
              <button type="button" onClick={() => setSelected(d)} className="font-medium text-ink text-left hover:underline">
                {d.full_name}
              </button>
            ),
          },
          { header: 'Phone', key: 'phone', render: d => <span className="text-ink-dim">{d.phone}</span> },
          { header: 'Vehicle', key: 'vehicle', render: d => <span className="text-ink-dim text-xs">{d.vehicle_plate} · {d.vehicle_type}</span> },
          { header: 'Status', key: 'status', render: d => <StatusBadge value={d.status} type="driver" /> },
          { header: 'Verified', key: 'verified', render: d => <VerifiedBadge isVerified={d.is_verified} /> },
          {
            header: 'Last Seen', key: 'last_seen',
            render: d => <span className="text-ink-dim text-xs">{d.last_seen_at ? new Date(d.last_seen_at).toLocaleString() : '—'}</span>,
          },
          {
            header: 'Action', key: 'action',
            render: d => (
              <button
                type="button"
                // Revoking takes the driver out of dispatch, so it asks first; verifying does not.
                onClick={() => (d.is_verified ? setRevoking(d) : verify(d.id, true))}
                disabled={isVerifying(d.id)}
                className={`text-xs px-3 py-1.5 rounded font-medium disabled:opacity-40 transition ${
                  d.is_verified
                    ? 'bg-lamp-red/10 text-lamp-red hover:bg-lamp-red/25 border border-lamp-red/40'
                    : 'bg-accent text-white hover:bg-navy'
                }`}
              >
                {isVerifying(d.id) ? '…' : d.is_verified ? 'Revoke' : 'Verify'}
              </button>
            ),
          },
        ]}
        rows={data?.items ?? []}
        keyFn={d => d.id}
        loading={loading}
        emptySlot={
          <EmptyState
            icon={Users}
            title="No drivers found"
            description={hasFilters ? 'Try adjusting your filters.' : 'Registered drivers will appear here.'}
          />
        }
        page={page}
        totalPages={Math.ceil(total / PAGE_SIZE)}
        onPageChange={setPage}
      />

      <ConfirmDialog
        open={revoking !== null}
        title="Revoke verification"
        message={`${revoking?.full_name ?? 'This driver'} will stop receiving ride requests until verified again.`}
        confirmLabel="Yes, revoke"
        cancelLabel="Keep verified"
        onCancel={() => setRevoking(null)}
        onConfirm={() => {
          const driver = revoking
          setRevoking(null)
          if (driver) void verify(driver.id, false)
        }}
      />

      <Modal open={selected !== null} onClose={() => setSelected(null)} title="Driver Details" width="lg">
        {selected && (
          <DriverDetail
            driver={selected}
            onVerify={v => (v ? verify(selected.id, true) : setRevoking(selected))}
            isVerifying={isVerifying(selected.id)}
          />
        )}
      </Modal>
    </div>
  )
}

function DriverDetail({ driver: d, onVerify, isVerifying }: { driver: Driver; onVerify: (v: boolean) => void; isVerifying: boolean }) {
  return (
    <div className="space-y-5">
      <div className="flex items-center gap-4">
        <div className="w-14 h-14 rounded-full bg-edge flex items-center justify-center text-steel font-bold text-xl" aria-hidden="true">
          {d.full_name.charAt(0).toUpperCase()}
        </div>
        <div>
          <p className="text-lg font-bold text-ink">{d.full_name}</p>
          <p className="text-sm text-ink-dim">{d.phone}</p>
        </div>
        <div className="ml-auto flex flex-col items-end gap-2">
          <StatusBadge value={d.status} type="driver" size="md" />
          <VerifiedBadge isVerified={d.is_verified} />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="bg-panel-inset rounded-md p-4">
          <p className="text-xs text-ink-dim font-medium mb-1">License No.</p>
          <p className="font-semibold text-ink">{d.license_no}</p>
        </div>
        <div className="bg-panel-inset rounded-md p-4">
          <p className="text-xs text-ink-dim font-medium mb-1">Vehicle Plate</p>
          <p className="font-semibold text-ink">{d.vehicle_plate}</p>
        </div>
        <div className="bg-panel-inset rounded-md p-4">
          <p className="text-xs text-ink-dim font-medium mb-1">Vehicle Type</p>
          <p className="font-semibold text-ink capitalize">{d.vehicle_type}</p>
        </div>
        <div className="bg-panel-inset rounded-md p-4">
          <p className="text-xs text-ink-dim font-medium mb-1">Member Since</p>
          <p className="font-semibold text-ink">{new Date(d.created_at).toLocaleDateString()}</p>
        </div>
      </div>

      {d.current_lat != null && d.current_lng != null && (
        <div className="flex items-center gap-3 bg-lamp-green/10 border border-lamp-green/40 rounded-md p-3 text-sm text-lamp-green">
          <MapPin size={14} aria-hidden="true" />
          <span>Last location: {d.current_lat.toFixed(4)}, {d.current_lng.toFixed(4)}</span>
        </div>
      )}
      {d.last_seen_at && (
        <div className="flex items-center gap-3 bg-panel-inset rounded-md p-3 text-xs text-ink-dim">
          <Clock size={12} aria-hidden="true" />
          Last seen: {new Date(d.last_seen_at).toLocaleString()}
        </div>
      )}

      <div className="flex gap-3 pt-2 border-t border-edge">
        <button
          type="button"
          onClick={() => onVerify(!d.is_verified)}
          disabled={isVerifying}
          className={`flex-1 py-2.5 rounded-md text-sm font-medium transition disabled:opacity-40 ${
            d.is_verified
              ? 'bg-lamp-red/10 text-lamp-red hover:bg-lamp-red/25 border border-lamp-red/40'
              : 'bg-accent text-white hover:bg-navy'
          }`}
        >
          {isVerifying ? '…' : d.is_verified ? 'Revoke Verification' : 'Verify Driver'}
        </button>
      </div>
    </div>
  )
}
