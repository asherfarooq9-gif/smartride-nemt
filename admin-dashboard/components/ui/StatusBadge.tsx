const RIDE_STATUS: Record<string, string> = {
  pending: 'bg-amber-100 text-amber-800 border-amber-200',
  driver_assigned: 'bg-blue-100 text-blue-800 border-blue-200',
  driver_en_route: 'bg-indigo-100 text-indigo-800 border-indigo-200',
  patient_picked_up: 'bg-cyan-100 text-cyan-800 border-cyan-200',
  arrived_at_hospital: 'bg-purple-100 text-purple-800 border-purple-200',
  completed: 'bg-green-100 text-green-800 border-green-200',
  cancelled: 'bg-red-100 text-red-800 border-red-200',
}

const DRIVER_STATUS: Record<string, string> = {
  available: 'bg-green-100 text-green-800 border-green-200',
  busy: 'bg-amber-100 text-amber-800 border-amber-200',
  offline: 'bg-gray-100 text-gray-600 border-gray-200',
}

interface Props {
  value: string
  type?: 'ride' | 'driver' | 'generic'
  size?: 'sm' | 'md'
}

export default function StatusBadge({ value, type = 'ride', size = 'sm' }: Props) {
  const map = type === 'driver' ? DRIVER_STATUS : RIDE_STATUS
  const cls = map[value] ?? 'bg-gray-100 text-gray-600 border-gray-200'
  const label = value.replace(/_/g, ' ')
  return (
    <span className={`inline-flex items-center border rounded-full font-medium capitalize ${cls} ${size === 'sm' ? 'px-2 py-0.5 text-xs' : 'px-3 py-1 text-sm'}`}>
      {label}
    </span>
  )
}
