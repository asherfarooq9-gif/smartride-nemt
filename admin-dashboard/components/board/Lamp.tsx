import Link from 'next/link'
import type { LucideIcon } from 'lucide-react'
import { isLit, type Tone } from '@/lib/board'

/** Tinted only when a person is needed; a quiet tile is plain white. */
const LOOK: Record<Tone, { box: string; text: string; chip: string }> = {
  alert: { box: 'border-lamp-red/60 bg-lamp-red/[0.07]', text: 'text-lamp-red', chip: 'bg-lamp-red/15' },
  attention: { box: 'border-lamp-amber/60 bg-lamp-amber/[0.08]', text: 'text-lamp-amber', chip: 'bg-lamp-amber/15' },
  info: { box: 'border-steel/50 bg-steel/[0.06]', text: 'text-steel', chip: 'bg-steel/15' },
  normal: { box: 'border-edge bg-panel-raised', text: 'text-lamp-green', chip: 'bg-lamp-green/10' },
  idle: { box: 'border-edge bg-panel-raised', text: 'text-steel', chip: 'bg-steel/10' },
}

interface Props {
  label: string
  count: number
  tone: Tone
  /** What the state means in words, for example "Overdue". */
  word: string
  /** One short, factual line, such as the longest wait. */
  detail?: string
  icon: LucideIcon
  pressed?: boolean
  onPress?: () => void
  href?: string
  shortcut?: string
  /** Newly worse and not yet acknowledged: the tile pulses a ring until it is. */
  flashing?: boolean
}

export default function Lamp({ label, count, tone, word, detail, icon: Icon, pressed, onPress, href, shortcut, flashing }: Props) {
  const look = LOOK[tone]
  const flash = flashing ? (tone === 'alert' ? 'tile-flash-red' : 'tile-flash-amber') : ''
  const body = (
    <>
      <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-lg ${look.chip}`}>
        <Icon size={20} className={look.text} aria-hidden="true" />
      </span>
      <span className="flex min-w-0 flex-1 flex-col items-start text-left">
        <span className="title text-[0.95rem] leading-tight text-ink">{label}</span>
        <span className="mt-0.5 flex items-center gap-1.5 text-xs text-ink-dim">
          <span aria-hidden="true" className={`h-1.5 w-1.5 shrink-0 rounded-full bg-current ${look.text}`} />
          <span className={isLit(tone) ? `font-medium ${look.text}` : ''}>{word}</span>
        </span>
        {detail && <span className="text-xs text-ink-dim">{detail}</span>}
      </span>
      <span className={`title text-4xl leading-none tabular-nums ${isLit(tone) ? look.text : 'text-ink'}`}>{count}</span>
      {shortcut && (
        <kbd
          aria-hidden="true"
          className="absolute right-2 top-1.5 hidden rounded border border-edge px-1 font-legend text-[0.65rem] text-ink-dim lg:block"
        >
          {shortcut}
        </kbd>
      )}
    </>
  )
  const shell = `press relative flex min-h-[5.5rem] w-full items-center gap-3 rounded-lg border px-4 py-3 shadow-[0_1px_2px_rgb(var(--shadow)/0.05)] transition-[border-color,background-color,box-shadow] duration-150 hover:border-edge-strong hover:shadow-[0_4px_14px_rgb(var(--shadow)/0.08)] ${look.box} ${flash} ${
    pressed ? '!border-steel ring-2 ring-steel/60' : ''
  }`

  if (href) {
    return (
      <Link href={href} className={shell}>
        {body}
      </Link>
    )
  }
  return (
    <button type="button" onClick={onPress} aria-pressed={pressed} className={shell}>
      {body}
    </button>
  )
}
