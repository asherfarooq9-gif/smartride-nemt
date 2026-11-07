'use client'
import { useState } from 'react'
import { api, errorMessage, type RideDetail } from '@/lib/api'
import StatusBadge from '@/components/ui/StatusBadge'
import Modal from '@/components/ui/Modal'
import ErrorBanner from '@/components/ui/ErrorBanner'
import { MapPin, Clock, User, Truck, Building2, Car } from 'lucide-react'

function formatConfidence(score: number | string): string {
  const value = Number(score)
  return Number.isFinite(value) ? `${(value * 100).toFixed(1)}%` : '—'
}

interface Props {
  ride: RideDetail
  /** Called after the ride was cancelled, so the caller can reload and close. */
  onCancelled: () => void
}

export default function RideDetailView({ ride, onCancelled }: Props) {
  const [cancelling, setCancelling] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [cancelError, setCancelError] = useState('')

  const canCancel = ride.status === 'pending' || ride.status === 'driver_assigned'

  async function cancelRide() {
    setConfirmOpen(false)
    setCancelling(true)
    setCancelError('')
    try {
      await api.cancelRide(ride.id)
      onCancelled()
    } catch (e: unknown) {
      setCancelError(errorMessage(e, 'Error cancelling ride'))
    } finally {
      setCancelling(false)
    }
  }

  return (
    <div className="space-y-5">
      <ErrorBanner message={cancelError} />
      <Modal open={confirmOpen} onClose={() => setConfirmOpen(false)} title="Cancel Ride" width="md">
        <p className="text-sm text-ink mb-6">Are you sure you want to cancel this ride? This cannot be undone.</p>
        <div className="flex gap-3 justify-end">
          <button type="button" onClick={() => setConfirmOpen(false)} className="px-4 py-2 text-sm border border-edge rounded-md hover:border-edge-strong transition">Keep ride</button>
          <button type="button" onClick={cancelRide} className="px-4 py-2 text-sm bg-lamp-red hover:bg-lamp-red/85 text-white rounded-md transition">Yes, cancel</button>
        </div>
      </Modal>

      <div className="flex items-center gap-3 flex-wrap">
        <StatusBadge value={ride.status} size="md" />
        <span className={`legend rounded-sm border px-3 py-1 text-sm ${ride.ride_type === 'emergency' ? 'border-lamp-red/40 bg-lamp-red/10 !text-lamp-red' : 'border-edge bg-panel-inset'}`}>
          {ride.ride_type}
        </span>
        {canCancel && (
          <button
            type="button"
            onClick={() => setConfirmOpen(true)}
            disabled={cancelling}
            className="ml-auto text-sm bg-lamp-red hover:bg-lamp-red/85 text-white px-4 py-1.5 rounded-md disabled:opacity-40 transition"
          >
            {cancelling ? 'Cancelling…' : 'Cancel Ride'}
          </button>
        )}
      </div>

      <div className="grid grid-cols-2 gap-4">
        <InfoBlock icon={MapPin} label="Pickup">
          {ride.pickup_address ?? `${ride.pickup_lat.toFixed(5)}, ${ride.pickup_lng.toFixed(5)}`}
        </InfoBlock>
        <InfoBlock icon={Clock} label="Requested">{new Date(ride.requested_at).toLocaleString()}</InfoBlock>
        {ride.driver_assigned_at && (
          <InfoBlock icon={Clock} label="Driver Assigned">{new Date(ride.driver_assigned_at).toLocaleString()}</InfoBlock>
        )}
        {ride.completed_at && (
          <InfoBlock icon={Clock} label="Completed">{new Date(ride.completed_at).toLocaleString()}</InfoBlock>
        )}
        {ride.estimated_fare_pkr != null && (
          <InfoBlock icon={Car} label="Estimated Fare">PKR {ride.estimated_fare_pkr}</InfoBlock>
        )}
        {ride.final_fare_pkr != null && (
          <InfoBlock icon={Car} label="Final Fare">PKR {ride.final_fare_pkr}</InfoBlock>
        )}
      </div>

      {ride.patient && (
        <Section icon={User} iconClass="text-steel" title="Patient">
          <p className="font-medium text-ink">{ride.patient.full_name}</p>
          <p className="text-sm text-ink-dim">{ride.patient.phone}</p>
          {ride.patient.mobility_needs && (
            <p className="text-xs text-lamp-amber bg-lamp-amber/10 rounded px-2 py-1 mt-1">{ride.patient.mobility_needs}</p>
          )}
        </Section>
      )}

      {ride.driver && (
        <Section icon={Truck} iconClass="text-lamp-green" title="Driver">
          <p className="font-medium text-ink">{ride.driver.full_name}</p>
          <p className="text-sm text-ink-dim">{ride.driver.phone} · {ride.driver.vehicle_plate} ({ride.driver.vehicle_type})</p>
        </Section>
      )}

      {ride.hospital && (
        <Section icon={Building2} iconClass="text-purple-600" title="Hospital">
          <p className="font-medium text-ink">{ride.hospital.name}</p>
          <p className="text-sm text-ink-dim">{ride.hospital.address}, {ride.hospital.city}</p>
        </Section>
      )}

      {ride.triage && (
        <div className="border border-edge rounded-md p-4">
          <p className="text-xs font-semibold text-ink-dim legend mb-3">AI Triage</p>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div><p className="text-xs text-ink-dim">Specialty</p><p className="font-medium capitalize">{ride.triage.predicted_specialty.replace(/_/g, ' ')}</p></div>
            <div><p className="text-xs text-ink-dim">Severity</p><p className="font-medium">Level {ride.triage.severity_level}</p></div>
            <div><p className="text-xs text-ink-dim">Confidence</p><p className="font-medium">{formatConfidence(ride.triage.confidence_score)}</p></div>
          </div>
          <p className="mt-2 text-xs text-ink-dim bg-panel-inset rounded p-2">{ride.triage.symptom_text}</p>
        </div>
      )}
    </div>
  )
}

function Section({ icon: Icon, iconClass, title, children }: {
  icon: React.ElementType; iconClass: string; title: string; children: React.ReactNode
}) {
  return (
    <div className="border border-edge rounded-md p-4 space-y-1">
      <div className="flex items-center gap-2 mb-2">
        <Icon size={14} className={iconClass} aria-hidden="true" />
        <span className="text-xs font-semibold text-ink-dim legend">{title}</span>
      </div>
      {children}
    </div>
  )
}

function InfoBlock({ icon: Icon, label, children }: { icon: React.ElementType; label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3">
      <div className="p-2 bg-panel-inset rounded shrink-0"><Icon size={13} className="text-ink-dim" aria-hidden="true" /></div>
      <div>
        <p className="text-xs text-ink-dim font-medium">{label}</p>
        <p className="text-sm text-ink font-medium mt-0.5">{children}</p>
      </div>
    </div>
  )
}
