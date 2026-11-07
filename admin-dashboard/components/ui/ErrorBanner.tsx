import { AlertCircle } from 'lucide-react'

interface Props {
  message: string | null | undefined
  className?: string
}

/** Inline error: announced to screen readers, rendered only when there is a message. */
export default function ErrorBanner({ message, className = '' }: Props) {
  if (!message) return null
  return (
    <div
      role="alert"
      className={`flex items-center gap-3 text-lamp-red bg-lamp-red/10 border border-lamp-red/40 rounded-md p-4 text-sm ${className}`}
    >
      <AlertCircle size={16} className="shrink-0" aria-hidden="true" />
      <span>{message}</span>
    </div>
  )
}
