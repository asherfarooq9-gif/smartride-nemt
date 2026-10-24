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
        <p className="text-sm text-gray-700 mb-6">Are you sure you want to cancel this ride? This cannot be undone.</p>
        <div className="flex gap-3 justify-end">
          <button type="button" onClick={() => setConfirmOpen(false)} className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:border-gray-300 transition">Keep ride</button>
          <button type="button" onClick={cancelRide} className="px-4 py-2 text-sm bg-red-600 hover:bg-red-700 text-white rounded-xl transition">Yes, cancel</button>
        </div>
      </Modal>

      <div className="flex items-center gap-3 flex-wrap">
        <StatusBadge value={ride.status} size="md" />
        <span className={`text-sm font-medium px-3 py-1 rounded-full border ${ride.ride_type === 'emergency' ? 'bg-red-50 border-red-200 text-red-700' : 'bg-blue-50 border-blue-200 text-blue-700'}`}>
          {ride.ride_type}
        </span>
        {canCancel && (
          <button
            type="button"
            onClick={() => setConfirmOpen(true)}
            disabled={cancelling}
            className="ml-auto text-sm bg-red-600 hover:bg-red-700 text-white px-4 py-1.5 rounded-xl disabled:opacity-40 transition"
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
        <Section icon={User} iconClass="text-blue-600" title="Patient">
          <p className="font-medium text-gray-900">{ride.patient.full_name}</p>
          <p className="text-sm text-gray-600">{ride.patient.phone}</p>
          {ride.patient.mobility_needs && (
            <p className="text-xs text-amber-700 bg-amber-50 rounded px-2 py-1 mt-1">{ride.patient.mobility_needs}</p>
          )}
        </Section>
      )}

      {ride.driver && (
        <Section icon={Truck} iconClass="text-green-600" title="Driver">
          <p className="font-medium text-gray-900">{ride.driver.full_name}</p>
          <p className="text-sm text-gray-600">{ride.driver.phone} · {ride.driver.vehicle_plate} ({ride.driver.vehicle_type})</p>
        </Section>
      )}

      {ride.hospital && (
        <Section icon={Building2} iconClass="text-purple-600" title="Hospital">
          <p className="font-medium text-gray-900">{ride.hospital.name}</p>
          <p className="text-sm text-gray-600">{ride.hospital.address}, {ride.hospital.city}</p>
        </Section>
      )}

      {ride.triage && (
        <div className="border border-gray-100 rounded-xl p-4">
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">AI Triage</p>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div><p className="text-xs text-gray-500">Specialty</p><p className="font-medium capitalize">{ride.triage.predicted_specialty.replace(/_/g, ' ')}</p></div>
            <div><p className="text-xs text-gray-500">Severity</p><p className="font-medium">Level {ride.triage.severity_level}</p></div>
            <div><p className="text-xs text-gray-500">Confidence</p><p className="font-medium">{formatConfidence(ride.triage.confidence_score)}</p></div>
          </div>
          <p className="mt-2 text-xs text-gray-600 bg-gray-50 rounded-lg p-2">{ride.triage.symptom_text}</p>
        </div>
      )}
    </div>
  )
}

function Section({ icon: Icon, iconClass, title, children }: {
  icon: React.ElementType; iconClass: string; title: string; children: React.ReactNode
}) {
  return (
    <div className="border border-gray-100 rounded-xl p-4 space-y-1">
      <div className="flex items-center gap-2 mb-2">
        <Icon size={14} className={iconClass} aria-hidden="true" />
        <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">{title}</span>
      </div>
      {children}
    </div>
  )
}

function InfoBlock({ icon: Icon, label, children }: { icon: React.ElementType; label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3">
      <div className="p-2 bg-gray-50 rounded-lg shrink-0"><Icon size={13} className="text-gray-500" aria-hidden="true" /></div>
      <div>
        <p className="text-xs text-gray-500 font-medium">{label}</p>
        <p className="text-sm text-gray-800 font-medium mt-0.5">{children}</p>
      </div>
    </div>
  )
}
