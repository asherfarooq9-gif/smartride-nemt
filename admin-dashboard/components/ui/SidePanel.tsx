'use client'
import { useEffect, useId, useRef } from 'react'
import { X } from 'lucide-react'

interface Props {
  open: boolean
  onClose: () => void
  title: string
  children: React.ReactNode
}

// How fast a flick must be, and how far it projects, to count as "dismiss".
const DECELERATION = 0.998
const DISMISS_FRACTION = 0.45
const DRAG_START_PX = 6

/** Where a flick would come to rest, the way scrolling decelerates (px, from px/s). */
function project(velocityPxPerSec: number): number {
  return ((velocityPxPerSec / 1000) * DECELERATION) / (1 - DECELERATION)
}

/** Past the edge, resistance grows: the panel follows the finger less the further it is pulled. */
function rubberband(distance: number, dimension: number): number {
  const c = 0.55
  return (distance * dimension * c) / (dimension + c * Math.abs(distance))
}

/**
 * A panel docked to the right edge that does not hide the page: no scrim, the board behind stays
 * usable. It slides on one axis in and out (same path both ways), is driven by transitions that
 * retarget from the live position (so it can be grabbed or reversed mid-flight), and can be
 * dragged away 1:1 with the pointer and settles from where it was released.
 */
export default function SidePanel({ open, onClose, title, children }: Props) {
  const panelRef = useRef<HTMLElement>(null)
  const titleId = useId()
  const drag = useRef<{ startX: number; samples: { x: number; t: number }[] } | null>(null)

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  function onPointerDown(e: React.PointerEvent<HTMLDivElement>) {
    if ((e.target as HTMLElement).closest('button')) return
    e.currentTarget.setPointerCapture(e.pointerId)
    drag.current = { startX: e.clientX, samples: [{ x: e.clientX, t: e.timeStamp }] }
  }

  function onPointerMove(e: React.PointerEvent<HTMLDivElement>) {
    const state = drag.current
    const panel = panelRef.current
    if (!state || !panel) return
    const delta = e.clientX - state.startX
    if (Math.abs(delta) < DRAG_START_PX) return
    state.samples = [...state.samples.slice(-4), { x: e.clientX, t: e.timeStamp }]
    // 1:1 to the right; resisted when pulled further open than rest.
    const x = delta > 0 ? delta : rubberband(delta, panel.offsetWidth)
    panel.style.transition = 'none'
    panel.style.transform = `translateX(${x}px)`
  }

  function onPointerUp(e: React.PointerEvent<HTMLDivElement>) {
    const state = drag.current
    const panel = panelRef.current
    drag.current = null
    if (!state || !panel) return
    const first = state.samples[0]
    const last = state.samples[state.samples.length - 1]
    const elapsed = Math.max(1, last.t - first.t)
    const velocity = ((last.x - first.x) / elapsed) * 1000
    const position = Math.max(0, e.clientX - state.startX)
    const projected = position + project(velocity)
    // Hand control back to the class transition: it animates from the position the panel is at now.
    panel.style.transition = ''
    panel.style.transform = ''
    if (projected > panel.offsetWidth * DISMISS_FRACTION) onClose()
  }

  return (
    <aside
      ref={panelRef}
      role="dialog"
      aria-labelledby={titleId}
      aria-hidden={!open}
      inert={!open}
      className={`side-panel glass fixed inset-y-0 right-0 z-30 !m-0 flex w-[min(34rem,100%)] flex-col border-l border-edge shadow-[-12px_0_40px_rgb(var(--shadow)/0.14)] transition-transform duration-[420ms] ease-[var(--spring)] ${
        open ? 'translate-x-0' : 'translate-x-full'
      }`}
    >
      <div
        className="flex h-14 shrink-0 cursor-grab touch-pan-y items-center justify-between border-b border-edge px-5 active:cursor-grabbing"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
      >
        <h2 id={titleId} className="title text-base">{title}</h2>
        <button
          type="button"
          onClick={onClose}
          className="rounded-md p-1.5 text-ink-dim transition-colors hover:bg-panel-inset hover:text-ink"
          aria-label="Close"
        >
          <X size={18} aria-hidden="true" />
        </button>
      </div>
      <div className="flex-1 overflow-y-auto px-5 py-5">{children}</div>
    </aside>
  )
}
