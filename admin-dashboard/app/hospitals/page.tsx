'use client'
import { useEffect, useState, useCallback } from 'react'
import { api, type Hospital } from '@/lib/api'
import Modal from '@/components/ui/Modal'
import LoadingRows from '@/components/ui/LoadingRows'
import { Building2, Plus, CheckCircle, XCircle, Activity } from 'lucide-react'

const ALL_SPECIALTIES = [
  'cardiology', 'neurology', 'orthopedics', 'obstetrics', 'pediatrics',
  'psychiatry', 'oncology', 'nephrology', 'pulmonology', 'gastroenterology',
  'ophthalmology', 'ent', 'dermatology', 'general_emergency', 'general', 'emergency'
]

const EMPTY: Partial<Hospital> = {
  name: '', address: '', city: 'Islamabad',
  lat: 33.6844, lng: 73.0479, ed_capacity: 100,
  specialties: [], phone: '', coordinator_phone: '',
}

function EdLoadBar({ current, capacity }: { current: number; capacity: number }) {
  const pct = capacity > 0 ? Math.min((current / capacity) * 100, 100) : 0
  const color = pct >= 80 ? 'bg-red-500' : pct >= 60 ? 'bg-amber-500' : 'bg-green-500'
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 bg-blue-100 rounded-full h-2 overflow-hidden">
        <div className={`h-full rounded-full ${color} transition-all`} style={{ width: `${pct}%` }} />
      </div>
      <span className={`text-xs font-medium ${pct >= 80 ? 'text-red-600' : 'text-gray-600'}`}>
        {current}/{capacity}
      </span>
    </div>
  )
}

export default function HospitalsPage() {
  const [hospitals, setHospitals] = useState<Hospital[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState<Partial<Hospital>>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [selected, setSelected] = useState<Hospital | null>(null)
  const [editForm, setEditForm] = useState<Partial<Hospital>>({})
  const [editSaving, setEditSaving] = useState(false)
  const [toggling, setToggling] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const d = await api.hospitals()
      setHospitals(d.items)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  function openDetail(h: Hospital) {
    setSelected(h)
    setEditForm({ name: h.name, address: h.address, city: h.city, lat: h.lat, lng: h.lng, ed_capacity: h.ed_capacity, phone: h.phone ?? '', coordinator_phone: h.coordinator_phone ?? '', specialties: [...h.specialties] })
  }

  async function save() {
    if (!form.name?.trim() || !form.address?.trim() || !form.city?.trim()) {
      alert('Name, address and city are required')
      return
    }
    setSaving(true)
    try {
      const created = await api.createHospital(form)
      setHospitals(hs => [created, ...hs])
      setShowForm(false)
      setForm(EMPTY)
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Error')
    } finally {
      setSaving(false)
    }
  }

  async function saveEdit() {
    if (!selected) return
    setEditSaving(true)
    try {
      const updated = await api.updateHospital(selected.id, editForm)
      setHospitals(hs => hs.map(h => h.id === selected.id ? updated : h))
      setSelected(updated)
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Error')
    } finally {
      setEditSaving(false)
    }
  }

  async function toggleActive(h: Hospital) {
    setToggling(h.id)
    try {
      const updated = await api.updateHospital(h.id, { is_active: !h.is_active })
      setHospitals(hs => hs.map(x => x.id === h.id ? updated : x))
      if (selected?.id === h.id) setSelected(updated)
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Error')
    } finally {
      setToggling(null)
    }
  }

  function toggleSpecialty(list: string[], s: string): string[] {
    return list.includes(s) ? list.filter(x => x !== s) : [...list, s]
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-blue-900">
          Hospitals <span className="text-blue-300 font-normal text-lg">({hospitals.length})</span>
        </h1>
        <button
          onClick={() => setShowForm(s => !s)}
          className="flex items-center gap-2 text-sm bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-xl transition shadow-sm"
        >
          <Plus size={15} />
          {showForm ? 'Cancel' : 'Add Hospital'}
        </button>
      </div>

      {error && <div className="text-red-600 bg-red-50 border border-red-200 rounded-xl p-4 text-sm">{error}</div>}

      {/* Add form */}
      {showForm && (
        <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-6">
          <h2 className="font-semibold text-blue-900 mb-4">New Hospital</h2>
          <div className="grid grid-cols-2 gap-4">
            {(['name', 'address', 'city'] as const).map(f => (
              <div key={f} className={f === 'address' ? 'col-span-2' : ''}>
                <label className="block text-xs font-medium text-gray-500 mb-1 capitalize">{f}</label>
                <input
                  value={(form[f] as string) ?? ''}
                  onChange={e => setForm(p => ({ ...p, [f]: e.target.value }))}
                  className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
                />
              </div>
            ))}
            {(['lat', 'lng', 'ed_capacity'] as const).map(f => (
              <div key={f}>
                <label className="block text-xs font-medium text-gray-500 mb-1">{f === 'ed_capacity' ? 'ED Capacity' : f.toUpperCase()}</label>
                <input
                  type="number" step="any"
                  value={(form[f] as number) ?? ''}
                  onChange={e => setForm(p => ({ ...p, [f]: parseFloat(e.target.value) || 0 }))}
                  className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
                />
              </div>
            ))}
            {(['phone', 'coordinator_phone'] as const).map(f => (
              <div key={f}>
                <label className="block text-xs font-medium text-gray-500 mb-1">{f === 'phone' ? 'Phone' : 'Coordinator Phone'}</label>
                <input
                  value={(form[f] as string) ?? ''}
                  onChange={e => setForm(p => ({ ...p, [f]: e.target.value }))}
                  className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
                />
              </div>
            ))}
            <div className="col-span-2">
              <label className="block text-xs font-medium text-gray-500 mb-2">Specialties</label>
              <div className="flex flex-wrap gap-2">
                {ALL_SPECIALTIES.map(s => (
                  <button
                    key={s}
                    type="button"
                    onClick={() => setForm(p => ({ ...p, specialties: toggleSpecialty(p.specialties ?? [], s) }))}
                    className={`text-xs px-3 py-1 rounded-full border transition ${(form.specialties ?? []).includes(s) ? 'bg-blue-600 text-white border-blue-600' : 'border-gray-200 text-gray-600 hover:border-blue-300'}`}
                  >
                    {s.replace(/_/g, ' ')}
                  </button>
                ))}
              </div>
            </div>
          </div>
          <div className="flex justify-end mt-4">
            <button onClick={save} disabled={saving}
              className="bg-green-600 hover:bg-green-700 text-white text-sm px-6 py-2.5 rounded-xl disabled:opacity-40 transition">
              {saving ? 'Saving…' : 'Save Hospital'}
            </button>
          </div>
        </div>
      )}

      <div className="bg-white rounded-2xl border border-blue-100 shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-blue-50 text-blue-600 text-xs uppercase border-b border-blue-100">
            <tr>
              {['Name', 'City', 'ED Load', 'Specialties', 'Active', 'Action'].map(h => (
                <th key={h} className="px-4 py-3 text-left font-medium">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-blue-50">
            {loading
              ? <LoadingRows cols={6} />
              : hospitals.length === 0
                ? <tr><td colSpan={6} className="px-4 py-16 text-center text-gray-400">
                    <Building2 size={32} className="mx-auto mb-3 opacity-30" />
                    <p>No hospitals</p>
                  </td></tr>
                : hospitals.map(h => (
                <tr key={h.id} className="hover:bg-blue-50/40 cursor-pointer transition-colors" onClick={() => openDetail(h)}>
                  <td className="px-4 py-3 font-medium text-gray-900 max-w-[200px]">{h.name}</td>
                  <td className="px-4 py-3 text-gray-500">{h.city}</td>
                  <td className="px-4 py-3 min-w-[140px]">
                    <EdLoadBar current={h.ed_current_load} capacity={h.ed_capacity} />
                  </td>
                  <td className="px-4 py-3 text-gray-500 text-xs max-w-[180px] truncate">
                    {h.specialties.slice(0, 3).map(s => s.replace(/_/g, ' ')).join(', ')}
                    {h.specialties.length > 3 ? ` +${h.specialties.length - 3}` : ''}
                  </td>
                  <td className="px-4 py-3">
                    {h.is_active
                      ? <span className="flex items-center gap-1 text-green-600 text-xs font-medium"><CheckCircle size={12} /> Active</span>
                      : <span className="flex items-center gap-1 text-gray-400 text-xs font-medium"><XCircle size={12} /> Inactive</span>}
                  </td>
                  <td className="px-4 py-3" onClick={e => e.stopPropagation()}>
                    <button
                      onClick={() => toggleActive(h)}
                      disabled={toggling === h.id}
                      className={`text-xs px-3 py-1.5 rounded-lg font-medium disabled:opacity-40 transition ${h.is_active ? 'bg-red-50 text-red-700 hover:bg-red-100 border border-red-200' : 'bg-green-50 text-green-700 hover:bg-green-100 border border-green-200'}`}
                    >
                      {toggling === h.id ? '…' : h.is_active ? 'Deactivate' : 'Activate'}
                    </button>
                  </td>
                </tr>
              ))
            }
          </tbody>
        </table>
      </div>

      {/* Hospital Detail Modal */}
      <Modal open={selected !== null} onClose={() => setSelected(null)} title="Hospital Details" width="xl">
        {selected && (
          <div className="space-y-5">
            {/* ED Load */}
            <div className="bg-blue-50 rounded-xl p-4">
              <div className="flex items-center gap-2 mb-3">
                <Activity size={14} className="text-blue-600" />
                <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">ED Capacity</span>
              </div>
              <EdLoadBar current={selected.ed_current_load} capacity={selected.ed_capacity} />
              <p className="text-xs text-gray-400 mt-2">{Math.round(selected.ed_current_load / selected.ed_capacity * 100)}% occupied</p>
            </div>

            {/* Edit form */}
            <div className="grid grid-cols-2 gap-4">
              {(['name', 'address', 'city'] as const).map(f => (
                <div key={f} className={f === 'address' ? 'col-span-2' : ''}>
                  <label className="block text-xs font-medium text-gray-500 mb-1 capitalize">{f}</label>
                  <input
                    value={(editForm[f] as string) ?? ''}
                    onChange={e => setEditForm(p => ({ ...p, [f]: e.target.value }))}
                    className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
                  />
                </div>
              ))}
              {(['lat', 'lng', 'ed_capacity'] as const).map(f => (
                <div key={f}>
                  <label className="block text-xs font-medium text-gray-500 mb-1">{f === 'ed_capacity' ? 'ED Capacity' : f.toUpperCase()}</label>
                  <input
                    type="number" step="any"
                    value={(editForm[f] as number) ?? ''}
                    onChange={e => setEditForm(p => ({ ...p, [f]: parseFloat(e.target.value) || 0 }))}
                    className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
                  />
                </div>
              ))}
              {(['phone', 'coordinator_phone'] as const).map(f => (
                <div key={f}>
                  <label className="block text-xs font-medium text-gray-500 mb-1">{f === 'phone' ? 'Phone' : 'Coordinator'}</label>
                  <input
                    value={(editForm[f] as string) ?? ''}
                    onChange={e => setEditForm(p => ({ ...p, [f]: e.target.value }))}
                    className="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
                  />
                </div>
              ))}
              <div className="col-span-2">
                <label className="block text-xs font-medium text-gray-500 mb-2">Specialties</label>
                <div className="flex flex-wrap gap-2">
                  {ALL_SPECIALTIES.map(s => (
                    <button
                      key={s}
                      type="button"
                      onClick={() => setEditForm(p => ({ ...p, specialties: toggleSpecialty(p.specialties ?? [], s) }))}
                      className={`text-xs px-3 py-1 rounded-full border transition ${(editForm.specialties ?? []).includes(s) ? 'bg-blue-600 text-white border-blue-600' : 'border-gray-200 text-gray-600 hover:border-blue-300'}`}
                    >
                      {s.replace(/_/g, ' ')}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="flex gap-3 pt-3 border-t border-gray-100">
              <button onClick={saveEdit} disabled={editSaving}
                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-2.5 rounded-xl text-sm font-medium disabled:opacity-40 transition">
                {editSaving ? 'Saving…' : 'Save Changes'}
              </button>
              <button
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
