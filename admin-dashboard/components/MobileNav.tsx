import Link from 'next/link'
import { NAV, isActive } from '@/components/nav'

/** Below 768px the rail becomes a bottom bar: the thumb reaches it, and content gets the full width. */
export default function MobileNav({ pathname }: { pathname: string }) {
  return (
    <nav
      aria-label="Main"
      className="glass fixed inset-x-0 bottom-0 z-20 flex justify-around border-t border-edge px-1 pb-[env(safe-area-inset-bottom)] md:hidden"
    >
      {NAV.map(({ href, label, icon: Icon }) => {
        const active = isActive(pathname, href)
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? 'page' : undefined}
            aria-label={label}
            className={`press flex min-h-[3.25rem] flex-1 flex-col items-center justify-center gap-0.5 rounded-lg text-[0.65rem] font-medium ${
              active ? 'text-steel' : 'text-ink-dim'
            }`}
          >
            <Icon size={20} aria-hidden="true" />
            <span aria-hidden="true">{label}</span>
          </Link>
        )
      })}
    </nav>
  )
}
