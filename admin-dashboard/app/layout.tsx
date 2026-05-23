'use client'
import './globals.css'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { clearToken, getToken } from '@/lib/api'
import { useEffect, useState } from 'react'
import {
  LayoutDashboard, Car, Users, Hospital, BarChart2,
  AlertTriangle, LogOut, Menu, X, UserCircle, Activity
} from 'lucide-react'

const NAV = [
  { href: '/', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/rides', label: 'Rides', icon: Car },
  { href: '/drivers', label: 'Drivers', icon: Users },
  { href: '/patients', label: 'Patients', icon: UserCircle },
  { href: '/hospitals', label: 'Hospitals', icon: Hospital },
  { href: '/analytics', label: 'Analytics', icon: BarChart2 },
  { href: '/alerts', label: 'Alerts', icon: AlertTriangle },
]

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const isLogin = pathname === '/login'
  const [collapsed, setCollapsed] = useState(true)

  useEffect(() => {
    if (!isLogin && !getToken()) router.replace('/login')
  }, [isLogin, router])

  function handleLogout() {
    clearToken()
    router.replace('/login')
  }

  if (isLogin) {
    return (
      <html lang="en">
        <body className="min-h-screen text-gray-900">{children}</body>
      </html>
    )
  }

  return (
    <html lang="en">
      <body className="bg-blue-50 text-gray-900 flex h-screen overflow-hidden">
        {/* Sidebar */}
        <aside
          className={`${collapsed ? 'w-16' : 'w-64'} bg-gradient-to-b from-blue-700 to-blue-900 text-white flex flex-col shrink-0 transition-all duration-300 ${collapsed ? 'cursor-pointer' : ''}`}
          onClick={collapsed ? () => setCollapsed(false) : undefined}
        >
          {/* Header */}
          <div className={`flex items-center ${collapsed ? 'justify-center px-3' : 'justify-between px-4'} py-4 border-b border-white/20`}>
            {!collapsed && (
              <div>
                <p className="font-bold text-base leading-tight text-white">SmartRide</p>
                <p className="text-blue-200 text-xs">NEMT Admin</p>
              </div>
            )}
            <button
              onClick={e => { e.stopPropagation(); setCollapsed(c => !c) }}
              className="p-1.5 rounded-lg hover:bg-white/10 text-white/70 hover:text-white transition"
              aria-label="Toggle sidebar"
            >
              {collapsed ? <Menu size={18} /> : <X size={18} />}
            </button>
          </div>

          {/* Nav */}
          <nav className="flex-1 py-4 space-y-0.5 px-2">
            {NAV.map(({ href, label, icon: Icon }) => {
              const active = pathname === href || (href !== '/' && pathname.startsWith(href))
              return (
                <Link
                  key={href}
                  href={href}
                  title={collapsed ? label : undefined}
                  onClick={e => e.stopPropagation()}
                  className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition ${
                    active
                      ? 'bg-white/20 text-white shadow-sm'
                      : 'text-white/70 hover:bg-white/10 hover:text-white'
                  }`}
                >
                  <Icon size={18} className="shrink-0" />
                  {!collapsed && <span>{label}</span>}
                </Link>
              )
            })}
          </nav>

          {/* Footer */}
          <div className="p-3 border-t border-white/20">
            <button
              onClick={e => { e.stopPropagation(); handleLogout() }}
              title={collapsed ? 'Sign out' : undefined}
              className="flex items-center gap-3 w-full rounded-lg px-3 py-2.5 text-sm font-medium text-white/60 hover:bg-white/10 hover:text-white transition"
            >
              <LogOut size={18} className="shrink-0" />
              {!collapsed && <span>Sign out</span>}
            </button>
          </div>
        </aside>

        {/* Main */}
        <main className="flex-1 overflow-auto">
          {/* Top bar */}
          <div className="sticky top-0 z-10 bg-white/90 backdrop-blur border-b border-blue-100 px-6 py-3 flex items-center gap-3">
            <Activity size={16} className="text-blue-600" />
            <span className="text-xs font-semibold text-blue-700 uppercase tracking-wider">
              {NAV.find(n => pathname === n.href || (n.href !== '/' && pathname.startsWith(n.href)))?.label ?? 'SmartRide Admin'}
            </span>
          </div>
          <div className="p-6">{children}</div>
        </main>
      </body>
    </html>
  )
}
