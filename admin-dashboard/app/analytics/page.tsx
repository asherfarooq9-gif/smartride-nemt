'use client'
import { useEffect, useState } from 'react'
import { api, type ForecastResponse } from '@/lib/api'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  LineChart, Line, Legend
} from 'recharts'
import { RefreshCw, Download, BarChart2, TrendingUp, Database } from 'lucide-react'

const CITIES = ['Islamabad', 'Rawalpindi']

export default function AnalyticsPage() {
  const [city, setCity] = useState('Islamabad')
  const [forecast, setForecast] = useState<ForecastResponse | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [snapshotMsg, setSnapshotMsg] = useState('')
  const [activeTab, setActiveTab] = useState<'forecast' | 'volume'>('forecast')

  async function loadForecast(c = city) {
    setLoading(true)
    setError('')
    try {
      const data = await api.forecast(c)
      setForecast(data)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Error loading forecast')
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
      setError(e instanceof Error ? e.message : 'Error writing snapshot')
    }
  }

  function changeCity(c: string) {
    setCity(c)
    loadForecast(c)
  }

  useEffect(() => { loadForecast() }, [])

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
                onClick={() => changeCity(c)}
                className={`px-4 py-1.5 rounded-lg text-sm font-medium transition ${city === c ? 'bg-white shadow text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}
              >
                {c}
              </button>
            ))}
          </div>
          <button
            onClick={() => loadForecast()}
            disabled={loading}
            className="flex items-center gap-2 text-sm bg-white border border-gray-200 hover:border-gray-300 px-4 py-2 rounded-xl shadow-sm transition disabled:opacity-50"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            Refresh
          </button>
          <button
            onClick={writeSnapshot}
            className="flex items-center gap-2 text-sm bg-slate-700 hover:bg-slate-800 text-white px-4 py-2 rounded-xl transition"
          >
            <Database size={14} />
            Write Snapshot
          </button>
        </div>
      </div>

      {snapshotMsg && (
        <div className="bg-green-50 border border-green-200 text-green-700 rounded-xl px-4 py-3 text-sm">{snapshotMsg}</div>
      )}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-600 rounded-xl px-4 py-3 text-sm">{error}</div>
      )}

      {/* KPI bar */}
      {forecast && (
        <div className="grid grid-cols-3 gap-4">
          <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-4">
            <p className="text-xs text-gray-400 font-medium uppercase tracking-wider">City</p>
            <p className="text-xl font-bold text-gray-900 mt-1">{forecast.city}</p>
          </div>
          <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-4">
            <p className="text-xs text-gray-400 font-medium uppercase tracking-wider">Method</p>
            <p className="text-xl font-bold text-gray-900 mt-1 capitalize">{forecast.method}</p>
          </div>
          <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-4">
            <p className="text-xs text-gray-400 font-medium uppercase tracking-wider">Peak Predicted</p>
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
            onClick={() => setActiveTab(t.id as 'forecast' | 'volume')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition ${activeTab === t.id ? 'bg-white shadow text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}
          >
            <t.icon size={14} />
            {t.label}
          </button>
        ))}
      </div>

      {/* Chart */}
      <div className="bg-white rounded-2xl border border-blue-100 shadow-sm p-6">
        {loading ? (
          <div className="h-64 flex items-center justify-center text-gray-400 animate-pulse">
            <RefreshCw size={24} className="animate-spin" />
          </div>
        ) : chartData.length === 0 ? (
          <div className="h-64 flex flex-col items-center justify-center text-gray-400 gap-3">
            <BarChart2 size={36} className="opacity-30" />
            <p className="text-sm">No data yet — write a snapshot first</p>
            <button onClick={writeSnapshot}
              className="text-sm bg-slate-700 text-white px-4 py-2 rounded-xl hover:bg-slate-800 transition flex items-center gap-2">
              <Database size={14} /> Write Snapshot
            </button>
          </div>
        ) : activeTab === 'forecast' ? (
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={chartData} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="time" tick={{ fontSize: 11, fill: '#9ca3af' }} />
              <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} />
              <Tooltip
                contentStyle={{ borderRadius: '12px', border: '1px solid #e5e7eb', fontSize: 12 }}
                formatter={(v: number) => [`${v} rides`, 'Predicted']}
              />
              <Bar dataKey="rides" fill="#3b82f6" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        ) : (
          <ResponsiveContainer width="100%" height={280}>
            <LineChart data={chartData} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="time" tick={{ fontSize: 11, fill: '#9ca3af' }} />
              <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} />
              <Tooltip contentStyle={{ borderRadius: '12px', border: '1px solid #e5e7eb', fontSize: 12 }} />
              <Legend />
              <Line type="monotone" dataKey="rides" stroke="#3b82f6" strokeWidth={2} dot={{ r: 3 }} name="Predicted rides" />
            </LineChart>
          </ResponsiveContainer>
        )}
      </div>

      {forecast && (
        <p className="text-xs text-gray-400">
          Generated: {new Date(forecast.generated_at).toLocaleString()}
        </p>
      )}
    </div>
  )
}
