'use client'
import { useCallback, useState } from 'react'
import { api, errorMessage } from '@/lib/api'
import { useApiData } from '@/lib/useApiData'
import ErrorBanner from '@/components/ui/ErrorBanner'
import dynamic from 'next/dynamic'
import { RefreshCw, Download, BarChart2, TrendingUp, Database } from 'lucide-react'
import { CHART_HEIGHT } from './chartHeight'

// recharts is large and only needed once there is data to draw, so it is not part
// of this page's first JavaScript. The placeholder has the chart's height, so the
// page does not jump when it arrives.
const ForecastCharts = dynamic(() => import('./ForecastCharts'), {
  ssr: false,
  loading: () => (
    <div
      className="flex items-center justify-center text-gray-500 animate-pulse"
      style={{ height: CHART_HEIGHT }}
      role="status"
      aria-label="Loading chart"
    >
      <RefreshCw size={24} className="animate-spin" />
    </div>
  ),
})

const CITIES = ['Islamabad', 'Rawalpindi']
const DEFAULT_CITY = CITIES[0]

export default function AnalyticsPage() {
  const [city, setCity] = useState(DEFAULT_CITY)
  const [snapshotMsg, setSnapshotMsg] = useState('')
  const [snapshotError, setSnapshotError] = useState('')
  const [activeTab, setActiveTab] = useState<'forecast' | 'volume'>('forecast')

  const fetchForecast = useCallback((signal: AbortSignal) => api.forecast(city, 12, signal), [city])
  const { data, error, loading, refreshing, reload } = useApiData(fetchForecast)
  const forecast = loading ? null : data

  async function writeSnapshot() {
    setSnapshotError('')
    try {
      await api.writeSnapshot(city)
      setSnapshotMsg(`Snapshot written for ${city}`)
      setTimeout(() => setSnapshotMsg(''), 3000)
      reload()
    } catch (e: unknown) {
      setSnapshotError(errorMessage(e, 'Error writing snapshot'))
    }
  }

  const chartData = forecast?.forecast.map(f => ({
    time: new Date(f.hour).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    rides: parseFloat(f.predicted_rides.toFixed(1)),
  })) ?? []

  const tabs = [
    { id: 'forecast', label: 'Demand Forecast', icon: BarChart2 },
    { id: 'volume', label: 'Trend (24h)', icon: TrendingUp },
  ]

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <h1 className="text-2xl font-bold text-blue-900">Analytics</h1>
        <div className="flex items-center gap-2 flex-wrap">
          {/* City toggle */}
          <div className="flex bg-blue-100/60 rounded-xl p-1 gap-1">
            {CITIES.map(c => (
              <button
                key={c}
                type="button"
                aria-pressed={city === c}
                onClick={() => setCity(c)}
                className={`px-4 py-1.5 rounded-lg text-sm font-medium transition ${city === c ? 'bg-white shadow text-gray-900' : 'text-gray-700 hover:text-gray-900'}`}
              >
                {c}
              </button>
            ))}
          </div>
          <button
            type="button"
            onClick={reload}
            disabled={loading || refreshing}
            className="flex items-center gap-2 text-sm bg-white border border-gray-200 hover:border-gray-300 px-4 py-2 rounded-xl shadow-sm transition disabled:opacity-50"
          >
            <RefreshCw size={14} className={loading || refreshing ? 'animate-spin' : ''} aria-hidden="true" />
            Refresh
          </button>
          <button
            type="button"
            onClick={writeSnapshot}
            className="flex items-center gap-2 text-sm bg-slate-700 hover:bg-slate-800 text-white px-4 py-2 rounded-xl transition"
          >
            <Database size={14} />
            Write Snapshot
          </button>
        </div>
      </div>

      {snapshotMsg && (
        <div role="status" className="bg-green-50 border border-green-200 text-green-700 rounded-xl px-4 py-3 text-sm">{snapshotMsg}</div>
      )}
      <ErrorBanner message={error ?? snapshotError} />

      {/* KPI bar */}
      {forecast && (
        <div className="grid grid-cols-3 gap-4">
          <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-4">
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wider">City</p>
            <p className="text-xl font-bold text-gray-900 mt-1">{forecast.city}</p>
          </div>
          <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-4">
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wider">Method</p>
            <p className="text-xl font-bold text-gray-900 mt-1 capitalize">{forecast.method}</p>
          </div>
          <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-4">
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wider">Peak Predicted</p>
            <p className="text-xl font-bold text-gray-900 mt-1">
              {chartData.length > 0 ? Math.max(...chartData.map(d => d.rides)) : '—'} rides/hr
            </p>
          </div>
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 bg-blue-100/60 rounded-xl p-1 w-fit">
        {tabs.map(t => (
          <button
            key={t.id}
            type="button"
            aria-pressed={activeTab === t.id}
            onClick={() => setActiveTab(t.id as 'forecast' | 'volume')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition ${activeTab === t.id ? 'bg-white shadow text-gray-900' : 'text-gray-700 hover:text-gray-900'}`}
          >
            <t.icon size={14} />
            {t.label}
          </button>
        ))}
      </div>

      {/* Chart */}
      <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-6">
        {loading ? (
          <div className="h-64 flex items-center justify-center text-gray-500 animate-pulse">
            <RefreshCw size={24} className="animate-spin" />
          </div>
        ) : chartData.length === 0 ? (
          <div className="h-64 flex flex-col items-center justify-center text-gray-500 gap-3">
            <BarChart2 size={36} className="opacity-30" />
            <p className="text-sm">No data yet — write a snapshot first</p>
            <button type="button" onClick={writeSnapshot}
              className="text-sm bg-slate-700 text-white px-4 py-2 rounded-xl hover:bg-slate-800 transition flex items-center gap-2">
              <Database size={14} /> Write Snapshot
            </button>
          </div>
        ) : (
          <ForecastCharts data={chartData} variant={activeTab} />
        )}
      </div>

      {forecast && (
        <p className="text-xs text-gray-600">
          Generated: {new Date(forecast.generated_at).toLocaleString()}
        </p>
      )}
    </div>
  )
}
