'use client'
import { useEffect, useState } from 'react'
import { api, type Hospital } from '@/lib/api'

const EMPTY: Partial<Hospital> = {
  name: '', address: '', city: 'Islamabad',
  lat: 33.6844, lng: 73.0479,
  ed_capacity: 100, specialties: [],
}

export default function HospitalsPage() {
  const [hospitals, setHospitals] = useState<Hospital[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState<Partial<Hospital>>(EMPTY)
  const [saving, setSaving] = useState(false)

  async function load() {
    setLoading(true)
    try {
      const d = await api.hospitals()
      setHospitals(d.items)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  async function save() {
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

  async function toggleActive(h: Hospital) {
    try {
      const updated = await api.updateHospital(h.id, { is_active: !h.is_active })
      setHospitals(hs => hs.map(x => x.id === h.id ? updated : x))
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Error')
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Hospitals ({hospitals.length})</h1>
        <button
          onClick={() => setShowForm(s => !s)}
          className="bg-blue-700 hover:bg-blue-800 text-white text-sm px-4 py-2 rounded-lg"
        >
          {showForm ? 'Cancel' : '+ Add Hospital'}
        </button>
      </div>

      {error && <p className="text-red-600 mb-4">{error}</p>}

      {showForm && (
        <div className="bg-white rounded-xl shadow-sm p-5 mb-6 grid grid-cols-2 gap-4">
          {(['name', 'address', 'city'] as const).map(f => (
            <div key={f}>
              <label className="block text-xs font-medium mb-1 capitalize">{f}</label>
              <input
                value={(form[f] as string) ?? ''}
                onChange={e => setForm(p => ({ ...p, [f]: e.target.value }))}
                className="w-full border rounded px-3 py-1.5 text-sm"
              />
            </div>
          ))}
          <div>
            <label className="block text-xs font-medium mb-1">Lat</label>
            <input type="number" step="any" value={form.lat}
              onChange={e => setForm(p => ({ ...p, lat: parseFloat(e.target.value) }))}
              className="w-full border rounded px-3 py-1.5 text-sm" />
          </div>
          <div>
            <label className="block text-xs font-medium mb-1">Lng</label>
            <input type="number" step="any" value={form.lng}
              onChange={e => setForm(p => ({ ...p, lng: parseFloat(e.target.value) }))}
              className="w-full border rounded px-3 py-1.5 text-sm" />
          </div>
          <div>
            <label className="block text-xs font-medium mb-1">ED Capacity</label>
            <input type="number" value={form.ed_capacity}
              onChange={e => setForm(p => ({ ...p, ed_capacity: parseInt(e.target.value) }))}
              className="w-full border rounded px-3 py-1.5 text-sm" />
          </div>
          <div className="col-span-2 flex justify-end">
            <button onClick={save} disabled={saving}
              className="bg-green-600 hover:bg-green-700 text-white text-sm px-5 py-2 rounded-lg disabled:opacity-40">
              {saving ? 'Saving…' : 'Save Hospital'}
            </button>
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 text-gray-500 uppercase text-xs">
            <tr>
              {['Name', 'City', 'ED Load', 'Specialties', 'Active', 'Action'].map(h => (
                <th key={h} className="px-4 py-3 text-left">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">Loading…</td></tr>
            ) : hospitals.map(h => (
              <tr key={h.id} className="hover:bg-gray-50">
                <td className="px-4 py-3 font-medium">{h.name}</td>
                <td className="px-4 py-3 text-gray-600">{h.city}</td>
                <td className="px-4 py-3">
                  <span className={h.ed_current_load / h.ed_capacity > 0.8 ? 'text-red-600 font-medium' : 'text-gray-700'}>
                    {h.ed_current_load}/{h.ed_capacity}
                  </span>
                </td>
                <td className="px-4 py-3 text-gray-500 text-xs">{h.specialties.slice(0, 3).join(', ')}{h.specialties.length > 3 ? '…' : ''}</td>
                <td className="px-4 py-3">
                  {h.is_active
                    ? <span className="text-green-600 font-medium">Active</span>
                    : <span className="text-gray-400">Inactive</span>}
                </td>
                <td className="px-4 py-3">
                  <button
                    onClick={() => toggleActive(h)}
                    className={`text-xs px-3 py-1 rounded ${h.is_active ? 'bg-red-100 text-red-700 hover:bg-red-200' : 'bg-green-100 text-green-700 hover:bg-green-200'}`}
                  >
                    {h.is_active ? 'Deactivate' : 'Activate'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
