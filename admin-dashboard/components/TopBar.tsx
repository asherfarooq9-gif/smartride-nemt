import { Activity } from 'lucide-react'
import { NAV, isActive } from '@/components/nav'

export default function TopBar({ pathname }: { pathname: string }) {
  const label = NAV.find(n => isActive(pathname, n.href))?.label ?? 'SmartRide Admin'
  return (
    <div className="sticky top-0 z-10 bg-white/90 backdrop-blur border-b border-blue-100 px-6 py-3 flex items-center gap-3">
      <Activity size={16} className="text-blue-600" aria-hidden="true" />
      <span className="text-xs font-semibold text-blue-700 uppercase tracking-wider">{label}</span>
    </div>
  )
}
