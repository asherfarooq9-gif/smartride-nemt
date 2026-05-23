import { type LucideIcon } from 'lucide-react'

interface EmptyStateProps {
  icon: LucideIcon
  title: string
  description?: string
}

export default function EmptyState({ icon: Icon, title, description }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="rounded-full bg-blue-50 p-4 mb-4">
        <Icon className="text-blue-300" size={32} />
      </div>
      <p className="text-blue-900 font-semibold text-base">{title}</p>
      {description && (
        <p className="text-gray-400 text-sm mt-1 max-w-xs">{description}</p>
      )}
    </div>
  )
}
