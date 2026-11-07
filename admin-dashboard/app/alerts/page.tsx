import EmptyState from '@/components/ui/EmptyState'
import { BellOff } from 'lucide-react'

// The backend has no alerts endpoint yet, so there is nothing real to list.
// This page used to ship hard-coded sample alerts that looked like live incidents;
// an operator must never mistake invented data for a real emergency.
export default function AlertsPage() {
  return (
    <div className="space-y-6">
      <h1 className="title text-3xl">Alerts</h1>
      <div className="bg-panel-raised rounded-md border border-edge ">
        <EmptyState
          icon={BellOff}
          title="Alerts are not connected yet"
          description="No alert feed is available from the backend, so nothing is shown here. Watch the Dashboard and Rides pages for live activity."
        />
      </div>
    </div>
  )
}
