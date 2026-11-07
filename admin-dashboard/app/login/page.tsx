'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { api, setToken, takeSessionExpired } from '@/lib/api'
import { Phone, Lock, AlertCircle, Eye, EyeOff } from 'lucide-react'
import { Mark } from '@/components/Sidebar'

export default function LoginPage() {
  const router = useRouter()
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  const [showHelp, setShowHelp] = useState(false)
  // Read once, when the page mounts after the redirect from an expired session.
  const [sessionExpired] = useState(takeSessionExpired)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const data = await api.login(phone, password)
      if (data.role !== 'admin') {
        // The server has now opened a session for this account; close it.
        await api.logoutWithToken(data.access_token)
        setError('Admin access only.')
        return
      }
      setToken(data.access_token)
      router.push('/')
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="grid min-h-screen place-items-center bg-panel px-4">
      <div className="w-full max-w-sm">
        <div className="mb-6 flex items-center gap-3">
          <Mark size={44} />
          <div className="leading-tight">
            <p className="title text-base">SmartRide</p>
            <p className="text-sm text-ink-dim">Dispatch console</p>
          </div>
        </div>

        <div className="panel-card">
          <div className="border-b border-edge px-6 py-4">
            <h1 className="title text-2xl">Sign in</h1>
            <p className="mt-1 text-sm text-ink-dim">Admin accounts only.</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5 px-6 py-6">
            {sessionExpired && !error && (
              <div role="status" className="rounded-xl border border-lamp-amber/40 bg-lamp-amber/10 px-4 py-3 text-sm text-lamp-amber">
                Your session expired. Please sign in again.
              </div>
            )}
            {error && (
              <div role="alert" className="flex items-center gap-2 rounded-xl border border-lamp-red/40 bg-lamp-red/10 px-4 py-3 text-sm text-lamp-red">
                <AlertCircle size={15} className="shrink-0" aria-hidden="true" />
                {error}
              </div>
            )}

            <div>
              <label htmlFor="phone" className="mb-1.5 block text-sm font-medium">Phone</label>
              <div className="relative">
                <Phone size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-dim" aria-hidden="true" />
                <input
                  id="phone"
                  name="phone"
                  type="text"
                  autoComplete="username"
                  value={phone}
                  onChange={e => setPhone(e.target.value)}
                  required
                  className="w-full rounded-lg border py-2.5 pl-9 pr-3 text-sm focus:border-steel focus:outline-none focus:ring-2 focus:ring-steel/40"
                  placeholder="+923001234567"
                />
              </div>
            </div>

            <div>
              <label htmlFor="password" className="mb-1.5 block text-sm font-medium">Password</label>
              <div className="relative">
                <Lock size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-dim" aria-hidden="true" />
                <input
                  id="password"
                  name="password"
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="current-password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  required
                  className="w-full rounded-lg border py-2.5 pl-9 pr-11 text-sm focus:border-steel focus:outline-none focus:ring-2 focus:ring-steel/40"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(v => !v)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  aria-pressed={showPassword}
                  className="press absolute right-1.5 top-1/2 grid h-8 w-8 -translate-y-1/2 place-items-center rounded-md text-ink-dim hover:bg-panel-inset hover:text-ink"
                >
                  {showPassword ? <EyeOff size={16} aria-hidden="true" /> : <Eye size={16} aria-hidden="true" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="press w-full rounded-lg bg-accent py-2.5 text-sm font-semibold text-white transition-colors hover:bg-navy disabled:opacity-50"
            >
              {loading ? 'Signing in…' : 'Sign in'}
            </button>

            <div className="text-center">
              <button
                type="button"
                onClick={() => setShowHelp(v => !v)}
                aria-expanded={showHelp}
                aria-controls="forgot-help"
                className="text-sm text-steel hover:underline"
              >
                Forgot password?
              </button>
              {showHelp && (
                <p id="forgot-help" className="mt-2 rounded-xl bg-panel-inset px-4 py-3 text-left text-sm text-ink-dim">
                  Admin passwords are reset by the system operator, not by email or SMS. Ask them to reset your
                  password, then sign in with the new one.
                </p>
              )}
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}
