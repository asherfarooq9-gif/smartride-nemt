'use client'
import { useEffect, useState } from 'react'
import { api, type ForecastResponse } from '@/lib/api'

export default function AnalyticsPage() {
  const [city, setCity] = useState('Islamabad')
  const [forecast, setForecast] = useState<ForecastResponse | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [snapshotMsg, setSnapshotMsg] = useState('')

  async function loadForecast() {
    setLoading(true)
    setError('')
    try {
      const data = await api.forecast(city)
      setForecast(data)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setLoading(false)
    }
  }

  async function writeSnapshot() {
    try {
      await api.writeSnapshot(city)
      setSnapshotMsg(`Snapshot written for ${city}`)
      setTimeout(() => setSnapshotMsg(''), 3000)
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Error')
    }
  }

  useEffect(() => { loadForecast() }, [])

  const maxRides = forecast ? Math.max(...forecast.forecast.map(f => f.predicted_rides), 1) : 1

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Analytics & Demand Forecast</h1>

      <div className="flex gap-3 mb-6 items-end flex-wrap">
        <div>
          <label className="block text-xs font-medium mb-1">City</label>
          <select
            value={city}
            onChange={e => setCity(e.target.value)}
            className="border rounded px-3 py-2 text-sm"
          >
            <option>Islamabad</option>
            <option>Rawalpindi</option>
          </select>
        </div>
        <button onClick={loadForecast} disabled={loading}
          className="bg-blue-700 hover:bg-blue-800 text-white text-sm px-4 py-2 rounded-lg disabled:opacity-40">
          {loading ? 'Loading…' : 'Refresh Forecast'}
        </button>
        <button onClick={writeSnapshot}
          className="bg-gray-700 hover:bg-gray-800 text-white text-sm px-4 py-2 rounded-lg">
          Write Snapshot
        </button>
        {snapshotMsg && <p className="text-green-600 text-sm">{snapshotMsg}</p>}
      </div>

      {error && <p className="text-red-600 mb-4">{error}</p>}

      {forecast && (
        <div className="bg-white rounded-xl shadow-sm p-6">
          <p className="text-sm text-gray-500 mb-1">
            Method: <span className="font-medium">{forecast.method}</span> ·
            Generated: {new Date(forecast.generated_at).toLocaleString()}
          </p>
          <p className="text-xs text-gray-400 mb-4">
            {forecast.forecast.length === 0
              ? 'No historical data yet — write a few snapshots first.'
              : 'Predicted rides per hour:'}
          </p>

          {/* Simple bar chart */}
          <div className="space-y-2">
            {forecast.forecast.map(f => {
              const pct = maxRides > 0 ? (f.predicted_rides / maxRides) * 100 : 0
              const label = new Date(f.hour).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
              return (
                <div key={f.hour} className="flex items-center gap-3">
                  <span className="text-xs text-gray-500 w-14 text-right">{label}</span>
                  <div className="flex-1 bg-gray-100 rounded h-6 overflow-hidden">
                    <div
                      className="bg-blue-500 h-full rounded transition-all"
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                  <span className="text-xs text-gray-700 w-8">{f.predicted_rides.toFixed(1)}</span>
                </div>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}
