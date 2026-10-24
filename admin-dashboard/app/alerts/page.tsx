import EmptyState from '@/components/ui/EmptyState'
import { BellOff } from 'lucide-react'

// The backend has no alerts endpoint yet, so there is nothing real to list.
// This page used to ship hard-coded sample alerts that looked like live incidents;
// an operator must never mistake invented data for a real emergency.
export default function AlertsPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-blue-900">Alerts</h1>
      <div className="bg-white rounded-2xl border border-blue-100 shadow-sm">
        <EmptyState
          icon={BellOff}
          title="Alerts are not connected yet"
          description="No alert feed is available from the backend, so nothing is shown here. Watch the Dashboard and Rides pages for live activity."
        />
      </div>
    </div>
  )
}
