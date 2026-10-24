'use client'
import { useCallback, useState } from 'react'
import { api, errorMessage, type Hospital, type HospitalInput } from '@/lib/api'
import { useApiData } from '@/lib/useApiData'
import Modal from '@/components/ui/Modal'
import DataTable from '@/components/ui/DataTable'
import EmptyState from '@/components/ui/EmptyState'
import ErrorBanner from '@/components/ui/ErrorBanner'
import HospitalFields from './HospitalFields'
import { Building2, Plus, CheckCircle, XCircle, Activity } from 'lucide-react'

const PAGE_SIZE = 50

const EMPTY_FORM: HospitalInput = {
  name: '', address: '', city: 'Islamabad',
  lat: 33.6844, lng: 73.0479, ed_capacity: 100,
  specialties: [], phone: '', coordinator_phone: '',
}

function toForm(h: Hospital): HospitalInput {
  return {
    name: h.name, address: h.address, city: h.city, lat: h.lat, lng: h.lng,
    ed_capacity: h.ed_capacity, phone: h.phone ?? '', coordinator_phone: h.coordinator_phone ?? '',
    specialties: [...h.specialties],
  }
}

function EdLoadBar({ current, capacity }: { current: number; capacity: number }) {
  const pct = capacity > 0 ? Math.min((current / capacity) * 100, 100) : 0
  const color = pct >= 80 ? 'bg-red-500' : pct >= 60 ? 'bg-amber-500' : 'bg-green-500'
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 bg-blue-100 rounded-full h-2 overflow-hidden">
        <div className={`h-full rounded-full ${color} transition-all`} style={{ width: `${pct}%` }} />
      </div>
      <span className={`text-xs font-medium ${pct >= 80 ? 'text-red-700' : 'text-gray-600'}`}>
        {current}/{capacity}
      </span>
    </div>
  )
}

function ActiveBadge({ isActive }: { isActive: boolean }) {
  return isActive
    ? <span className="flex items-center gap-1 text-green-700 text-xs font-medium"><CheckCircle size={12} /> Active</span>
    : <span className="flex items-center gap-1 text-gray-500 text-xs font-medium"><XCircle size={12} /> Inactive</span>
}

export default function HospitalsPage() {
  const [page, setPage] = useState(1)
  const fetchHospitals = useCallback((signal: AbortSignal) => api.hospitals(page, PAGE_SIZE, signal), [page])
  const { data, error, loading, reload } = useApiData(fetchHospitals)
  const hospitals = data?.items ?? []

  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState<HospitalInput>(EMPTY_FORM)
  const [saving, setSaving] = useState(false)
  const [formError, setFormError] = useState('')
  const [selected, setSelected] = useState<Hospital | null>(null)
  const [editForm, setEditForm] = useState<HospitalInput>(EMPTY_FORM)
  const [editSaving, setEditSaving] = useState(false)
  const [editError, setEditError] = useState('')
  const [toggling, setToggling] = useState<string | null>(null)
  const [actionError, setActionError] = useState('')

  function openDetail(h: Hospital) {
    setSelected(h)
    setEditForm(toForm(h))
    setEditError('')
  }

  async function save() {
    if (!form.name.trim() || !form.address.trim() || !form.city.trim()) {
      setFormError('Name, address and city are required')
      return
    }
    setSaving(true)
    setFormError('')
    try {
      await api.createHospital(form)
      reload()
      setShowForm(false)
      setForm(EMPTY_FORM)
    } catch (e: unknown) {
      setFormError(errorMessage(e, 'Could not save the hospital'))
    } finally {
      setSaving(false)
    }
  }

  async function saveEdit() {
    if (!selected) return
    setEditSaving(true)
    setEditError('')
    try {
      const updated = await api.updateHospital(selected.id, editForm)
      setSelected(updated)
      reload()
    } catch (e: unknown) {
      setEditError(errorMessage(e, 'Could not save the changes'))
    } finally {
      setEditSaving(false)
    }
  }

  async function toggleActive(h: Hospital) {
    setToggling(h.id)
    setActionError('')
    setEditError('')
    try {
      const updated = await api.updateHospital(h.id, { is_active: !h.is_active })
      if (selected?.id === h.id) setSelected(updated)
      reload()
    } catch (e: unknown) {
      const message = errorMessage(e, 'Could not update the hospital')
      if (selected?.id === h.id) setEditError(message)
      else setActionError(message)
    } finally {
      setToggling(null)
    }
  }

  function toggleForm() {
    setShowForm(s => !s)
    setFormError('')
  }

  const total = data?.total ?? 0

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-blue-900">
          Hospitals <span className="text-blue-600 font-normal text-lg">({total})</span>
        </h1>
        <button
          type="button"
          onClick={toggleForm}
          aria-expanded={showForm}
          className="flex items-center gap-2 text-sm bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-xl transition shadow-sm"
        >
          <Plus size={15} aria-hidden="true" />
          {showForm ? 'Cancel' : 'Add Hospital'}
        </button>
      </div>

      <ErrorBanner message={error ?? actionError} />

      {showForm && (
        <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-6">
          <h2 className="font-semibold text-blue-900 mb-4">New Hospital</h2>
          <HospitalFields idPrefix="new-hospital" value={form} onChange={setForm} />
          <ErrorBanner message={formError} className="mt-4" />
          <div className="flex justify-end mt-4">
            <button type="button" onClick={save} disabled={saving}
              className="bg-green-600 hover:bg-green-700 text-white text-sm px-6 py-2.5 rounded-xl disabled:opacity-40 transition">
              {saving ? 'Saving…' : 'Save Hospital'}
            </button>
          </div>
        </div>
      )}

      <DataTable
        columns={[
          {
            header: 'Name', key: 'name', className: 'max-w-[200px]',
            render: h => (
              <button type="button" onClick={() => openDetail(h)} className="font-medium text-gray-900 text-left hover:underline">
                {h.name}
              </button>
            ),
          },
          { header: 'City', key: 'city', render: h => <span className="text-gray-500">{h.city}</span> },
          {
            header: 'ED Load', key: 'ed_load', className: 'min-w-[140px]',
            render: h => <EdLoadBar current={h.ed_current_load} capacity={h.ed_capacity} />,
          },
          {
            header: 'Specialties', key: 'specialties', className: 'max-w-[180px]',
            render: h => (
              <span className="block truncate text-gray-500 text-xs">
                {h.specialties.slice(0, 3).map(s => s.replace(/_/g, ' ')).join(', ')}
                {h.specialties.length > 3 ? ` +${h.specialties.length - 3}` : ''}
              </span>
            ),
          },
          { header: 'Active', key: 'active', render: h => <ActiveBadge isActive={h.is_active} /> },
          {
            header: 'Action', key: 'action',
            render: h => (
              <button
                type="button"
                onClick={() => toggleActive(h)}
                disabled={toggling === h.id}
                aria-label={`${h.is_active ? 'Deactivate' : 'Activate'} ${h.name}`}
                className={`text-xs px-3 py-1.5 rounded-lg font-medium disabled:opacity-40 transition ${h.is_active ? 'bg-red-50 text-red-700 hover:bg-red-100 border border-red-200' : 'bg-green-50 text-green-700 hover:bg-green-100 border border-green-200'}`}
              >
                {toggling === h.id ? '…' : h.is_active ? 'Deactivate' : 'Activate'}
              </button>
            ),
          },
        ]}
        rows={hospitals}
        keyFn={h => h.id}
        loading={loading}
        emptySlot={
          <EmptyState icon={Building2} title="No hospitals yet" description="Add a hospital using the button above." />
        }
        page={page}
        totalPages={Math.ceil(total / PAGE_SIZE)}
        onPageChange={setPage}
      />

      <Modal open={selected !== null} onClose={() => setSelected(null)} title="Hospital Details" width="xl">
        {selected && (
          <div className="space-y-5">
            <div className="bg-blue-50 rounded-xl p-4">
              <div className="flex items-center gap-2 mb-3">
                <Activity size={14} className="text-blue-600" aria-hidden="true" />
                <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">ED Capacity</span>
              </div>
              <EdLoadBar current={selected.ed_current_load} capacity={selected.ed_capacity} />
              <p className="text-xs text-gray-500 mt-2">
                {selected.ed_capacity > 0 ? Math.round(selected.ed_current_load / selected.ed_capacity * 100) : 0}% occupied
              </p>
            </div>

            <HospitalFields idPrefix="edit-hospital" value={editForm} onChange={setEditForm} />
            <ErrorBanner message={editError} />

            <div className="flex gap-3 pt-3 border-t border-gray-100">
              <button type="button" onClick={saveEdit} disabled={editSaving}
                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-2.5 rounded-xl text-sm font-medium disabled:opacity-40 transition">
                {editSaving ? 'Saving…' : 'Save Changes'}
              </button>
              <button
                type="button"
                onClick={() => toggleActive(selected)}
                disabled={toggling === selected.id}
                className={`px-5 py-2.5 rounded-xl text-sm font-medium disabled:opacity-40 transition ${selected.is_active ? 'bg-red-50 text-red-700 hover:bg-red-100 border border-red-200' : 'bg-green-50 text-green-700 hover:bg-green-100 border border-green-200'}`}
              >
                {selected.is_active ? 'Deactivate' : 'Activate'}
              </button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  )
}
