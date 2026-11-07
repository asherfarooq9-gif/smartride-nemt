import {
  LayoutDashboard, Car, Users, Hospital, BarChart2, AlertTriangle, UserCircle, Map,
} from 'lucide-react'

export const NAV = [
  { href: '/', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/rides', label: 'Rides', icon: Car },
  { href: '/drivers', label: 'Drivers', icon: Users },
  { href: '/patients', label: 'Patients', icon: UserCircle },
  { href: '/hospitals', label: 'Hospitals', icon: Hospital },
  { href: '/map', label: 'Live map', icon: Map },
  { href: '/analytics', label: 'Analytics', icon: BarChart2 },
  { href: '/alerts', label: 'Alerts', icon: AlertTriangle },
]

export function isActive(pathname: string, href: string): boolean {
  return pathname === href || (href !== '/' && pathname.startsWith(href))
}
