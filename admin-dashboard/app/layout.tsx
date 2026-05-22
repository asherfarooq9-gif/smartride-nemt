'use client'
import type { Metadata } from 'next'
import './globals.css'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { clearToken, getToken } from '@/lib/api'
import { useEffect } from 'react'

const NAV = [
  { href: '/', label: 'Dashboard' },
  { href: '/rides', label: 'Rides' },
  { href: '/drivers', label: 'Drivers' },
  { href: '/hospitals', label: 'Hospitals' },
  { href: '/analytics', label: 'Analytics' },
]

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const isLogin = pathname === '/login'

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
        <body className="bg-gray-50 text-gray-900">{children}</body>
      </html>
    )
  }

  return (
    <html lang="en">
      <body className="bg-gray-50 text-gray-900 flex h-screen overflow-hidden">
        {/* Sidebar */}
        <aside className="w-56 bg-blue-800 text-white flex flex-col shrink-0">
          <div className="px-5 py-4 border-b border-blue-700">
            <p className="font-bold text-lg leading-tight">SmartRide</p>
            <p className="text-blue-300 text-xs">NEMT Admin</p>
          </div>
          <nav className="flex-1 py-4 space-y-1 px-2">
            {NAV.map(({ href, label }) => (
              <Link
                key={href}
                href={href}
                className={`block rounded-lg px-3 py-2 text-sm font-medium transition ${
                  pathname === href
                    ? 'bg-blue-600 text-white'
                    : 'text-blue-100 hover:bg-blue-700'
                }`}
              >
                {label}
              </Link>
            ))}
          </nav>
          <button
            onClick={handleLogout}
            className="m-4 text-xs text-blue-300 hover:text-white text-left"
          >
            Sign out
          </button>
        </aside>

        {/* Main */}
        <main className="flex-1 overflow-auto p-6">{children}</main>
      </body>
    </html>
  )
}
