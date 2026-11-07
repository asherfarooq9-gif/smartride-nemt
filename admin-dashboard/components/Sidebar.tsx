'use client'
import Link from 'next/link'
import { useState } from 'react'
import { HeartPulse, LogOut, PanelLeftOpen, PanelLeftClose } from 'lucide-react'
import { signOut } from '@/lib/session'
import { NAV, isActive } from '@/components/nav'

/** The mark is a blue app-icon tile with a heartbeat line: care plus movement, no logo file needed. */
export function Mark({ size = 36 }: { size?: number }) {
  return (
    <span
      aria-hidden="true"
      style={{ width: size, height: size }}
      className="grid shrink-0 place-items-center rounded-[28%] bg-accent text-white shadow-sm"
    >
      <HeartPulse size={Math.round(size * 0.55)} strokeWidth={2.2} />
    </span>
  )
}

export default function Sidebar({ pathname }: { pathname: string }) {
  const [collapsed, setCollapsed] = useState(false)
  const labelClass = collapsed ? 'sr-only' : ''
  const item =
    'press flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors'

  return (
    <aside
      className={`${collapsed ? 'w-16' : 'w-56'} hidden shrink-0 flex-col border-r border-edge bg-panel-raised/80 text-ink backdrop-blur-xl transition-[width] duration-300 ease-[var(--spring)] md:flex`}
    >
      <div className={`flex h-14 items-center ${collapsed ? 'justify-center' : 'gap-3 px-4'}`}>
        <Mark />
        {!collapsed && (
          <div className="min-w-0 leading-tight">
            <p className="title text-base">SmartRide</p>
            <p className="text-xs text-ink-dim">Dispatch</p>
          </div>
        )}
      </div>

      <nav id="sidebar-nav" aria-label="Main" className="flex-1 space-y-1 p-2">
        {NAV.map(({ href, label, icon: Icon }) => {
          const active = isActive(pathname, href)
          return (
            <Link
              key={href}
              href={href}
              title={collapsed ? label : undefined}
              aria-current={active ? 'page' : undefined}
              className={`${item} ${active ? 'bg-steel/10 text-steel' : 'text-ink-dim hover:bg-panel-inset hover:text-ink'}`}
            >
              <Icon size={19} className="shrink-0" aria-hidden="true" />
              <span className={labelClass}>{label}</span>
            </Link>
          )
        })}
      </nav>

      <div className="space-y-1 border-t border-edge p-2">
        <button
          type="button"
          onClick={() => setCollapsed(c => !c)}
          className={`${item} text-ink-dim hover:bg-panel-inset hover:text-ink`}
          aria-label="Collapse sidebar"
          aria-expanded={!collapsed}
          aria-controls="sidebar-nav"
        >
          {collapsed ? <PanelLeftOpen size={19} aria-hidden="true" /> : <PanelLeftClose size={19} aria-hidden="true" />}
          <span className={labelClass}>Collapse</span>
        </button>
        <button
          type="button"
          onClick={signOut}
          title={collapsed ? 'Sign out' : undefined}
          className={`${item} text-ink-dim hover:bg-panel-inset hover:text-ink`}
        >
          <LogOut size={19} className="shrink-0" aria-hidden="true" />
          <span className={labelClass}>Sign out</span>
        </button>
      </div>
    </aside>
  )
}
