'use client'
import { useEffect, useId, useRef } from 'react'
import { X } from 'lucide-react'

interface Props {
  open: boolean
  onClose: () => void
  title: string
  children: React.ReactNode
  width?: 'md' | 'lg' | 'xl' | '2xl'
}

const WIDTHS = { md: 'max-w-md', lg: 'max-w-lg', xl: 'max-w-xl', '2xl': 'max-w-2xl' }

/**
 * Native <dialog>.showModal() gives what hand-rolled modals get wrong: a focus
 * trap (the rest of the page is inert), initial focus inside the dialog, focus
 * restored to the trigger on close, and Escape closing only the top-most dialog
 * when modals are stacked (e.g. a confirmation over the ride detail).
 */
export default function Modal({ open, onClose, title, children, width = 'lg' }: Props) {
  const dialogRef = useRef<HTMLDialogElement>(null)
  const titleId = useId()
  // Where the press began. Selecting text in an input and releasing over the backdrop
  // fires a click on the dialog; closing then would throw away the admin's edits.
  const pressStartedOnBackdrop = useRef(false)

  useEffect(() => {
    const dialog = dialogRef.current
    if (!open || !dialog) return
    dialog.showModal()
    return () => dialog.close()
  }, [open])

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby={titleId}
      onCancel={e => {
        // React bubbles `cancel` from a nested dialog to its parent; only react to our own.
        if (e.target !== e.currentTarget) return
        // Keep `open` as the single source of truth: the effect closes the dialog.
        e.preventDefault()
        onClose()
      }}
      onMouseDown={e => {
        pressStartedOnBackdrop.current = e.target === e.currentTarget
      }}
      onClick={e => {
        // Only a press that both started and ended on the backdrop closes it.
        if (e.target === e.currentTarget && pressStartedOnBackdrop.current) onClose()
      }}
      className={`m-auto w-[calc(100%-2rem)] ${WIDTHS[width]} rounded-2xl bg-white p-0 text-gray-900 shadow-2xl backdrop:bg-black/50 backdrop:backdrop-blur-sm`}
    >
      {open && (
        <div className="flex max-h-[90vh] flex-col">
          <div className="flex items-center justify-between px-6 py-4 border-b border-blue-100">
            <h2 id={titleId} className="text-lg font-semibold text-blue-900">{title}</h2>
            <button
              type="button"
              onClick={onClose}
              className="p-1.5 rounded-lg hover:bg-blue-50 transition text-gray-500 hover:text-blue-900"
              aria-label="Close"
            >
              <X size={18} aria-hidden="true" />
            </button>
          </div>
          <div className="overflow-y-auto flex-1 px-6 py-4">{children}</div>
        </div>
      )}
    </dialog>
  )
}
