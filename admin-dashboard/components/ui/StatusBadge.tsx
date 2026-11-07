import { RIDE_STATUS, DRIVER_STATUS, statusLabel, type Tone } from '@/lib/board'

const TONE_CLASS: Record<Tone, string> = {
  alert: 'border-lamp-red/40 text-lamp-red bg-lamp-red/10',
  attention: 'border-lamp-amber/40 text-lamp-amber bg-lamp-amber/10',
  normal: 'border-lamp-green/40 text-lamp-green bg-lamp-green/10',
  info: 'border-steel/40 text-steel bg-steel/10',
  idle: 'border-edge text-ink-dim bg-panel-inset',
}

interface Props {
  value: string
  type?: 'ride' | 'driver' | 'generic'
  size?: 'sm' | 'md'
}

/** A status is a word plus a pip, never colour alone. */
export default function StatusBadge({ value, type = 'ride', size = 'sm' }: Props) {
  const map = type === 'driver' ? DRIVER_STATUS : RIDE_STATUS
  const tone: Tone = map[value] ?? 'idle'
  return (
    <span
      className={`inline-flex items-center gap-1.5 whitespace-nowrap rounded-md border font-medium ${TONE_CLASS[tone]} ${size === 'sm' ? 'px-2 py-0.5 text-xs' : 'px-3 py-1 text-sm'}`}
    >
      <span aria-hidden="true" className="h-1.5 w-1.5 rounded-full bg-current" />
      {statusLabel(value)}
    </span>
  )
}
