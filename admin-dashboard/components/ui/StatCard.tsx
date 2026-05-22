import type { LucideIcon } from 'lucide-react'

const ACCENT: Record<string, string> = {
  blue: 'bg-blue-50 border-blue-200 text-blue-700',
  red: 'bg-red-50 border-red-200 text-red-700',
  amber: 'bg-amber-50 border-amber-200 text-amber-700',
  green: 'bg-green-50 border-green-200 text-green-700',
  gray: 'bg-gray-50 border-gray-200 text-gray-600',
  purple: 'bg-purple-50 border-purple-200 text-purple-700',
  cyan: 'bg-cyan-50 border-cyan-200 text-cyan-700',
}

interface Props {
  label: string
  value: number | string
  icon: LucideIcon
  color?: string
  subtitle?: string
  onClick?: () => void
}

export default function StatCard({ label, value, icon: Icon, color = 'blue', subtitle, onClick }: Props) {
  const cls = ACCENT[color] ?? ACCENT.blue
  return (
    <div
      className={`bg-white rounded-2xl border p-5 shadow-sm hover:shadow-md transition-shadow ${onClick ? 'cursor-pointer hover:scale-[1.01] transition-transform' : ''}`}
      onClick={onClick}
    >
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-medium text-gray-500 uppercase tracking-wider">{label}</p>
          <p className="text-3xl font-bold text-gray-900 mt-1">{value}</p>
          {subtitle && <p className="text-xs text-gray-400 mt-1">{subtitle}</p>}
        </div>
        <div className={`p-3 rounded-xl border ${cls}`}>
          <Icon size={20} />
        </div>
      </div>
    </div>
  )
}
