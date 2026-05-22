'use client'
import { useEffect, useState } from 'react'
import { AlertTriangle, CheckCircle, RefreshCw, AlertCircle, Clock } from 'lucide-react'

interface Alert {
  id: string
  severity: 'critical' | 'warning' | 'info'
  title: string
  description: string
  created_at: string
  acknowledged: boolean
}

const SEV_STYLES = {
  critical: { bg: 'bg-red-50 border-red-200', icon: 'text-red-600', badge: 'bg-red-100 text-red-700 border-red-200' },
  warning: { bg: 'bg-amber-50 border-amber-200', icon: 'text-amber-600', badge: 'bg-amber-100 text-amber-700 border-amber-200' },
  info: { bg: 'bg-blue-50 border-blue-200', icon: 'text-blue-600', badge: 'bg-blue-100 text-blue-700 border-blue-200' },
}

const MOCK_ALERTS: Alert[] = [
  {
    id: '1',
    severity: 'critical',
    title: 'Hospital ED Over Capacity',
    description: 'Benazir Bhutto Hospital is at 190/250 capacity (76%). Monitor closely.',
    created_at: new Date(Date.now() - 5 * 60000).toISOString(),
    acknowledged: false,
  },
  {
    id: '2',
    severity: 'warning',
    title: 'Ride Pending > 10 min',
    description: 'Ride #3b7c2a1d has been in pending state for over 10 minutes with no driver assigned.',
    created_at: new Date(Date.now() - 12 * 60000).toISOString(),
    acknowledged: false,
  },
  {
    id: '3',
    severity: 'warning',
    title: 'Low Driver Availability',
    description: 'Only 1 driver available in Islamabad zone. Consider alerting offline drivers.',
    created_at: new Date(Date.now() - 25 * 60000).toISOString(),
    acknowledged: false,
  },
  {
    id: '4',
    severity: 'info',
    title: 'Daily Snapshot Created',
    description: 'Analytics snapshot for Islamabad was written successfully.',
    created_at: new Date(Date.now() - 60 * 60000).toISOString(),
    acknowledged: true,
  },
]

function timeAgo(iso: string) {
  const diff = Date.now() - new Date(iso).getTime()
  const min = Math.floor(diff / 60000)
  if (min < 1) return 'just now'
  if (min < 60) return `${min}m ago`
  return `${Math.floor(min / 60)}h ago`
}

export default function AlertsPage() {
  const [alerts, setAlerts] = useState<Alert[]>(MOCK_ALERTS)
  const [filter, setFilter] = useState<'all' | 'active' | 'acknowledged'>('active')
  const [refreshing, setRefreshing] = useState(false)

  useEffect(() => {
    const interval = setInterval(() => setAlerts(a => [...a]), 30000)
    return () => clearInterval(interval)
  }, [])

  function acknowledge(id: string) {
    setAlerts(prev => prev.map(a => a.id === id ? { ...a, acknowledged: true } : a))
  }

  function refresh() {
    setRefreshing(true)
    setTimeout(() => setRefreshing(false), 800)
  }

  const filtered = alerts.filter(a => {
    if (filter === 'active') return !a.acknowledged
    if (filter === 'acknowledged') return a.acknowledged
    return true
  })

  const activeCount = alerts.filter(a => !a.acknowledged).length

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold text-gray-900">Alerts</h1>
          {activeCount > 0 && (
            <span className="bg-red-600 text-white text-xs font-bold px-2 py-0.5 rounded-full">{activeCount}</span>
          )}
        </div>
        <button onClick={refresh} disabled={refreshing}
          className="flex items-center gap-2 text-sm bg-white border border-gray-200 hover:border-gray-300 px-4 py-2 rounded-xl shadow-sm transition disabled:opacity-50">
          <RefreshCw size={14} className={refreshing ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-1 bg-gray-100 rounded-xl p-1 w-fit">
        {(['all', 'active', 'acknowledged'] as const).map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-1.5 rounded-lg text-sm font-medium capitalize transition ${filter === f ? 'bg-white shadow text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}
          >
            {f} {f === 'active' && activeCount > 0 ? `(${activeCount})` : ''}
          </button>
        ))}
      </div>

      <div className="space-y-3">
        {filtered.length === 0 ? (
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-16 text-center text-gray-400">
            <CheckCircle size={36} className="mx-auto mb-3 text-green-400" />
            <p className="font-medium">All clear</p>
            <p className="text-sm mt-1">No {filter === 'active' ? 'active' : ''} alerts</p>
          </div>
        ) : filtered.map(alert => {
          const sev = SEV_STYLES[alert.severity]
          return (
            <div key={alert.id} className={`border rounded-2xl p-5 flex items-start gap-4 ${sev.bg} ${alert.acknowledged ? 'opacity-60' : ''}`}>
              <div className={sev.icon + ' mt-0.5'}>
                {alert.severity === 'critical'
                  ? <AlertCircle size={20} />
                  : alert.severity === 'warning'
                    ? <AlertTriangle size={20} />
                    : <AlertCircle size={20} />}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <p className="font-semibold text-gray-900">{alert.title}</p>
                  <span className={`text-xs px-2 py-0.5 rounded-full border font-medium capitalize ${sev.badge}`}>
                    {alert.severity}
                  </span>
                  {alert.acknowledged && (
                    <span className="text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-700 border border-green-200 font-medium flex items-center gap-1">
                      <CheckCircle size={10} /> Acknowledged
                    </span>
                  )}
                </div>
                <p className="text-sm text-gray-700 mt-1">{alert.description}</p>
                <div className="flex items-center gap-1 text-xs text-gray-400 mt-2">
                  <Clock size={10} /> {timeAgo(alert.created_at)}
                </div>
              </div>
              {!alert.acknowledged && (
                <button
                  onClick={() => acknowledge(alert.id)}
                  className="shrink-0 text-xs bg-white hover:bg-gray-50 border border-gray-200 px-3 py-1.5 rounded-lg font-medium text-gray-700 transition shadow-sm"
                >
                  Acknowledge
                </button>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}
