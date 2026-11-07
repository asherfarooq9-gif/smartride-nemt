'use client'
import { useEffect, useSyncExternalStore } from 'react'
import { Moon, Sun } from 'lucide-react'

type Theme = 'light' | 'dark'
const KEY = 'smartride-theme'

function systemTheme(): Theme {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

/** The page's data-theme attribute is the single source of truth; this hook just watches it. */
function subscribe(onChange: () => void) {
  const observer = new MutationObserver(onChange)
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] })
  return () => observer.disconnect()
}
const readTheme = () => document.documentElement.dataset.theme ?? null

/** Follows the system until the person picks a side; the pick is remembered in this browser only. */
export default function ThemeToggle() {
  const theme = useSyncExternalStore(subscribe, readTheme, () => null)

  useEffect(() => {
    let saved: string | null = null
    try {
      saved = localStorage.getItem(KEY)
    } catch {
      // Storage blocked: fall back to the system setting.
    }
    document.documentElement.dataset.theme = saved === 'light' || saved === 'dark' ? saved : systemTheme()
  }, [])

  function toggle() {
    const next: Theme = theme === 'dark' ? 'light' : 'dark'
    document.documentElement.dataset.theme = next
    try {
      localStorage.setItem(KEY, next)
    } catch {
      // Not saved; still applies for this visit.
    }
  }

  const isDark = theme === 'dark'
  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
      className="press rounded-lg p-2 text-ink-dim hover:bg-panel-inset hover:text-ink"
    >
      {isDark ? <Sun size={18} aria-hidden="true" /> : <Moon size={18} aria-hidden="true" />}
    </button>
  )
}
