import './globals.css'
import type { Metadata, Viewport } from 'next'
import { connection } from 'next/server'
import AppShell from '@/components/AppShell'

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
    <html lang="en">
      <body className="bg-blue-50 text-gray-900">
        <AppShell>{children}</AppShell>
      </body>
    </html>
  )
}
