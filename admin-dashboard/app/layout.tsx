import './globals.css'
import type { Metadata, Viewport } from 'next'
import { connection } from 'next/server'
import { DM_Sans } from 'next/font/google'
import AppShell from '@/components/AppShell'

const body = DM_Sans({ subsets: ['latin'], weight: ['400', '500', '600', '700'], variable: '--font-body', display: 'swap' })

export const metadata: Metadata = {
  title: { default: 'SmartRide Admin', template: '%s | SmartRide Admin' },
  description: 'SmartRide NEMT operations console',
  robots: { index: false, follow: false },
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
}

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  // Render per request: the CSP nonce from proxy.ts is attached to Next's inline
  // scripts at render time, which a statically prerendered page cannot do.
  await connection()
  return (
    <html lang="en" className={body.variable}>
      <body>
        <AppShell>{children}</AppShell>
      </body>
    </html>
  )
}
