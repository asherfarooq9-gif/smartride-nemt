import { useCallback, useRef, useState } from 'react'

/**
 * Tracks which rows (by id) have a request in flight, so several can be busy at
 * once. A single "currently busy id" state forgets the first row the moment the
 * second one is clicked, and the first row's request then clears the second's flag.
 * `run` ignores a call for an id that is already busy, so a double click sends one
 * request.
 */
export function useInFlight() {
  const active = useRef(new Set<string>())
  const [ids, setIds] = useState<ReadonlySet<string>>(() => new Set())

  const run = useCallback(async (id: string, task: () => Promise<void>) => {
    if (active.current.has(id)) return
    active.current.add(id)
    setIds(new Set(active.current))
    try {
      await task()
    } finally {
      active.current.delete(id)
      setIds(new Set(active.current))
    }
  }, [])

  const isBusy = useCallback((id: string) => ids.has(id), [ids])
  return { isBusy, run }
}
