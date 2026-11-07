'use client'
import { useEffect, useState } from 'react'
import { LogOut } from 'lucide-react'
import { signOut } from '@/lib/session'
import ThemeToggle from '@/components/ThemeToggle'

/** Ticks once a second, and only this small component re-renders when it does. */
function Clock() {
  const [now, setNow] = useState<Date | null>(null)
  useEffect(() => {
    const tick = () => setNow(new Date())
    tick()
    const id = setInterval(tick, 1000)
    return () => clearInterval(id)
  }, [])
  return (
    <time dateTime={now?.toISOString()} className="title text-base tabular-nums" aria-label="Local time">
      {now ? now.toLocaleTimeString([], { hour12: false }) : '--:--:--'}
    </time>
  )
}

/** A translucent bar: pages scroll underneath it, so it never takes a solid strip of the screen. */
export default function TopBar() {
  return (
    <div className="glass sticky top-0 z-10 flex h-14 items-center justify-between border-b border-edge px-4 md:px-6">
      <span className="text-sm text-ink-dim">Islamabad and Rawalpindi pilot</span>
      <div className="flex items-center gap-4">
        <div className="flex items-center gap-2">
          <span className="hidden text-xs text-ink-dim sm:inline">Local time</span>
          <Clock />
        </div>
        <ThemeToggle />
        <button
          type="button"
          onClick={signOut}
          aria-label="Sign out"
          className="press rounded-lg p-2 text-ink-dim hover:bg-panel-inset hover:text-ink md:hidden"
        >
          <LogOut size={18} aria-hidden="true" />
        </button>
      </div>
    </div>
  )
}
