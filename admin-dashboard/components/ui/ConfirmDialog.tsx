'use client'
import { useEffect, useRef } from 'react'
import Modal from './Modal'

interface Props {
  open: boolean
  title: string
  /** What will happen, in plain words. */
  message: string
  confirmLabel: string
  cancelLabel?: string
  onConfirm: () => void
  onCancel: () => void
}

/** A yes/no question before a consequential action. Cancel is the safe, default-focused choice. */
export default function ConfirmDialog({ open, title, message, confirmLabel, cancelLabel = 'Keep as is', onConfirm, onCancel }: Props) {
  const cancelRef = useRef<HTMLButtonElement>(null)

  // <dialog>.showModal() (in Modal's effect) moves focus to its first control after
  // React has mounted the content, which overrides a plain autoFocus. This effect
  // runs after it, so the safe choice ends up focused: Enter keeps things as they are.
  useEffect(() => {
    if (open) cancelRef.current?.focus()
  }, [open])

  return (
    <Modal open={open} onClose={onCancel} title={title} width="md">
      <p className="text-sm text-gray-700 mb-6">{message}</p>
      <div className="flex gap-3 justify-end">
        <button type="button" ref={cancelRef} onClick={onCancel} className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:border-gray-300 transition">
          {cancelLabel}
        </button>
        <button type="button" onClick={onConfirm} className="px-4 py-2 text-sm bg-red-600 hover:bg-red-700 text-white rounded-xl transition">
          {confirmLabel}
        </button>
      </div>
    </Modal>
  )
}
