import type { HospitalInput } from '@/lib/api'

export const ALL_SPECIALTIES = [
  'cardiology', 'neurology', 'orthopedics', 'obstetrics', 'pediatrics',
  'psychiatry', 'oncology', 'nephrology', 'pulmonology', 'gastroenterology',
  'ophthalmology', 'ent', 'dermatology', 'general_emergency', 'general', 'emergency',
]

type TextKey = 'name' | 'address' | 'city' | 'phone' | 'coordinator_phone'
type NumberKey = 'lat' | 'lng' | 'ed_capacity'

const TEXT_FIELDS: { key: TextKey; label: string; wide?: boolean }[] = [
  { key: 'name', label: 'Name' },
  { key: 'address', label: 'Address', wide: true },
  { key: 'city', label: 'City' },
]
const NUMBER_FIELDS: { key: NumberKey; label: string }[] = [
  { key: 'lat', label: 'LAT' },
  { key: 'lng', label: 'LNG' },
  { key: 'ed_capacity', label: 'ED Capacity' },
]
const PHONE_FIELDS: { key: TextKey; label: string }[] = [
  { key: 'phone', label: 'Phone' },
  { key: 'coordinator_phone', label: 'Coordinator Phone' },
]

const INPUT_CLASS =
  'w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400'
const LABEL_CLASS = 'block text-xs font-medium text-gray-500 mb-1'

interface Props {
  /** Prefix for the input ids, so two forms on one page never collide. */
  idPrefix: string
  value: HospitalInput
  onChange: (next: HospitalInput) => void
}

export function toggleSpecialty(list: string[], specialty: string): string[] {
  return list.includes(specialty) ? list.filter(x => x !== specialty) : [...list, specialty]
}

export default function HospitalFields({ idPrefix, value, onChange }: Props) {
  const textInput = (key: TextKey, label: string, wide = false) => (
    <div key={key} className={wide ? 'col-span-2' : ''}>
      <label htmlFor={`${idPrefix}-${key}`} className={LABEL_CLASS}>{label}</label>
      <input
        id={`${idPrefix}-${key}`}
        value={value[key]}
        onChange={e => onChange({ ...value, [key]: e.target.value })}
        className={INPUT_CLASS}
      />
    </div>
  )

  return (
    <div className="grid grid-cols-2 gap-4">
      {TEXT_FIELDS.map(f => textInput(f.key, f.label, f.wide))}
      {NUMBER_FIELDS.map(f => (
        <div key={f.key}>
          <label htmlFor={`${idPrefix}-${f.key}`} className={LABEL_CLASS}>{f.label}</label>
          <input
            id={`${idPrefix}-${f.key}`}
            type="number"
            step="any"
            value={value[f.key]}
            onChange={e => onChange({ ...value, [f.key]: parseFloat(e.target.value) || 0 })}
            className={INPUT_CLASS}
          />
        </div>
      ))}
      {PHONE_FIELDS.map(f => textInput(f.key, f.label))}
      <fieldset className="col-span-2">
        <legend className="block text-xs font-medium text-gray-500 mb-2">Specialties</legend>
        <div className="flex flex-wrap gap-2">
          {ALL_SPECIALTIES.map(s => {
            const isSelected = value.specialties.includes(s)
            return (
              <button
                key={s}
                type="button"
                aria-pressed={isSelected}
                onClick={() => onChange({ ...value, specialties: toggleSpecialty(value.specialties, s) })}
                className={`text-xs px-3 py-1 rounded-full border transition ${isSelected ? 'bg-blue-600 text-white border-blue-600' : 'border-gray-200 text-gray-600 hover:border-blue-300'}`}
              >
                {s.replace(/_/g, ' ')}
              </button>
            )
          })}
        </div>
      </fieldset>
    </div>
  )
}
