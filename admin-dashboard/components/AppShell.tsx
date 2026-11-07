'use client'
import { useEffect, useSyncExternalStore } from 'react'
import { usePathname, useRouter } from 'next/navigation'
import { hasToken, subscribeToken } from '@/lib/api'
import Sidebar from '@/components/Sidebar'
import TopBar from '@/components/TopBar'
import MobileNav from '@/components/MobileNav'
import EmergencyBanner from '@/components/EmergencyBanner'

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
    // Already signed in: the login form has nothing to offer.
    if (isLogin && isSignedIn === true) router.replace('/')
  }, [isLogin, isSignedIn, router])

  if (isLogin) return <>{children}</>
  if (!isSignedIn) return <p role="status" className="sr-only">Checking your session…</p>

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar pathname={pathname} />
      <div className="flex min-w-0 flex-1 flex-col">
        <EmergencyBanner />
        <main className="min-h-0 min-w-0 flex-1 overflow-auto">
          <TopBar />
          <div className="mx-auto max-w-[1600px] p-4 pb-24 md:p-6 md:pb-6">{children}</div>
        </main>
      </div>
      <MobileNav pathname={pathname} />
    </div>
  )
}
