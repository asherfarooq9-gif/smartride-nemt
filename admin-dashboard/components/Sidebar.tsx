'use client'
import Link from 'next/link'
import { useState } from 'react'
import { LogOut, Menu, X } from 'lucide-react'
import { api, clearToken } from '@/lib/api'
import { NAV, isActive } from '@/components/nav'

async function signOut() {
  try {
    await api.logout()
  } catch {
    // Intentional: sign-out is best effort. If the server cannot revoke the token
    // (offline, already expired) the user must still be signed out locally.
  }
  // AppShell sees the token disappear and navigates to /login.
  clearToken()
}

export default function Sidebar({ pathname }: { pathname: string }) {
  const [collapsed, setCollapsed] = useState(true)
  const labelClass = collapsed ? 'sr-only' : ''

  return (
    <aside
      className={`${collapsed ? 'w-16' : 'w-64'} bg-gradient-to-b from-blue-700 to-blue-900 text-white flex flex-col shrink-0 transition-all duration-300`}
    >
      <div className={`flex items-center ${collapsed ? 'justify-center px-3' : 'justify-between px-4'} py-4 border-b border-white/20`}>
        {!collapsed && (
          <div>
            <p className="font-bold text-base leading-tight text-white">SmartRide</p>
            <p className="text-blue-200 text-xs">NEMT Admin</p>
          </div>
        )}
        <button
          type="button"
          onClick={() => setCollapsed(c => !c)}
          className="p-1.5 rounded-lg hover:bg-white/10 text-white/70 hover:text-white transition"
          aria-label="Toggle sidebar"
          aria-expanded={!collapsed}
          aria-controls="sidebar-nav"
        >
          {collapsed ? <Menu size={18} /> : <X size={18} />}
        </button>
      </div>

      <nav id="sidebar-nav" aria-label="Main" className="flex-1 py-4 space-y-0.5 px-2">
        {NAV.map(({ href, label, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            title={collapsed ? label : undefined}
            aria-current={isActive(pathname, href) ? 'page' : undefined}
            className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition ${
              isActive(pathname, href)
                ? 'bg-white/20 text-white shadow-sm'
                : 'text-white/70 hover:bg-white/10 hover:text-white'
            }`}
          >
            <Icon size={18} className="shrink-0" aria-hidden="true" />
            <span className={labelClass}>{label}</span>
          </Link>
        ))}
      </nav>

      <div className="p-3 border-t border-white/20">
        <button
          type="button"
          onClick={signOut}
          title={collapsed ? 'Sign out' : undefined}
          className="flex items-center gap-3 w-full rounded-lg px-3 py-2.5 text-sm font-medium text-white/60 hover:bg-white/10 hover:text-white transition"
        >
          <LogOut size={18} className="shrink-0" aria-hidden="true" />
          <span className={labelClass}>Sign out</span>
        </button>
      </div>
    </aside>
  )
}
