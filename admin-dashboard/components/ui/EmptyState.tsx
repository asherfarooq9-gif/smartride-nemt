import { type LucideIcon } from 'lucide-react'

interface EmptyStateProps {
  icon: LucideIcon
  title: string
  description?: string
}

export default function EmptyState({ icon: Icon, title, description }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="mb-4 rounded-sm border border-edge bg-panel-inset p-3">
        <Icon className="text-ink-dim" size={26} aria-hidden="true" />
      </div>
      <p className="title text-lg">{title}</p>
      {description && <p className="mt-1.5 max-w-sm text-sm text-ink-dim">{description}</p>}
    </div>
  )
}
