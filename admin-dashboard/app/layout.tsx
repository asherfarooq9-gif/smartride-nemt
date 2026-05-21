import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'SmartRide Admin',
  description: 'SmartRide NEMT Admin Dashboard',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-gray-50 text-gray-900">
        <nav className="bg-blue-700 text-white px-6 py-3 flex items-center gap-3">
          <span className="font-bold text-lg">SmartRide NEMT</span>
          <span className="text-blue-200">Admin Dashboard</span>
        </nav>
        <main className="p-6">{children}</main>
      </body>
    </html>
  )
}
