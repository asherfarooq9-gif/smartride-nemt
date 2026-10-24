'use client'
import { useEffect, useSyncExternalStore } from 'react'
import { usePathname, useRouter } from 'next/navigation'
import { hasToken, subscribeToken } from '@/lib/api'
import Sidebar from '@/components/Sidebar'
import TopBar from '@/components/TopBar'

/**
 * Auth gate + chrome. Children (and therefore their API calls) render only after
 * the token check passes; until then, and while redirecting, nothing of the
 * protected UI is shown. The server snapshot is `null` ("unknown"), so the
 * server-rendered HTML for protected routes never contains protected content.
 */
export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const isLogin = pathname === '/login'
  const isSignedIn = useSyncExternalStore(subscribeToken, hasToken, () => null)

  useEffect(() => {
    if (!isLogin && isSignedIn === false) router.replace('/login')
  }, [isLogin, isSignedIn, router])

  if (isLogin) return <>{children}</>
  if (!isSignedIn) return <p role="status" className="sr-only">Checking your session…</p>

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar pathname={pathname} />
      <main className="min-w-0 flex-1 overflow-auto">
        <TopBar pathname={pathname} />
        <div className="p-6">{children}</div>
      </main>
    </div>
  )
}
