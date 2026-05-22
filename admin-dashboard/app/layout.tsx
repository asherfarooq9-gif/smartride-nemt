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
  const [collapsed, setCollapsed] = useState(false)

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
        <body className="bg-gradient-to-br from-slate-900 to-blue-950 min-h-screen text-gray-900">{children}</body>
      </html>
    )
  }

  return (
    <html lang="en">
      <body className="bg-gray-50 text-gray-900 flex h-screen overflow-hidden">
        {/* Sidebar */}
        <aside className={`${collapsed ? 'w-16' : 'w-60'} bg-slate-900 text-white flex flex-col shrink-0 transition-all duration-300`}>
          {/* Header */}
          <div className={`flex items-center ${collapsed ? 'justify-center px-3' : 'justify-between px-4'} py-4 border-b border-slate-700`}>
            {!collapsed && (
              <div>
                <p className="font-bold text-base leading-tight text-white">SmartRide</p>
                <p className="text-slate-400 text-xs">NEMT Admin</p>
              </div>
            )}
            <button
              onClick={() => setCollapsed(c => !c)}
              className="p-1.5 rounded-lg hover:bg-slate-700 text-slate-400 hover:text-white transition"
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
                  className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition ${
                    active
                      ? 'bg-blue-600 text-white'
                      : 'text-slate-300 hover:bg-slate-700 hover:text-white'
                  }`}
                >
                  <Icon size={18} className="shrink-0" />
                  {!collapsed && <span>{label}</span>}
                </Link>
              )
            })}
          </nav>

          {/* Footer */}
          <div className="p-3 border-t border-slate-700">
            <button
              onClick={handleLogout}
              title={collapsed ? 'Sign out' : undefined}
              className="flex items-center gap-3 w-full rounded-lg px-3 py-2.5 text-sm font-medium text-slate-400 hover:bg-slate-700 hover:text-white transition"
            >
              <LogOut size={18} className="shrink-0" />
              {!collapsed && <span>Sign out</span>}
            </button>
          </div>
        </aside>

        {/* Main */}
        <main className="flex-1 overflow-auto">
          {/* Top bar */}
          <div className="sticky top-0 z-10 bg-white/80 backdrop-blur border-b border-gray-100 px-6 py-3 flex items-center gap-3">
            <Activity size={16} className="text-blue-600" />
            <span className="text-xs font-medium text-gray-500 uppercase tracking-wider">
              {NAV.find(n => pathname === n.href || (n.href !== '/' && pathname.startsWith(n.href)))?.label ?? 'SmartRide Admin'}
            </span>
          </div>
          <div className="p-6">{children}</div>
        </main>
      </body>
    </html>
  )
}
