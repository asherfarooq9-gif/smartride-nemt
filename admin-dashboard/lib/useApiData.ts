import { useEffect, useState } from 'react'
import { errorMessage, isAbortError } from '@/lib/api'

type Fetcher<T> = (signal: AbortSignal) => Promise<T>

interface Settled<T> {
  fetcher: Fetcher<T>
  reloads: number
  data: T | null
  error: string | null
}

/**
 * Loads data and re-loads whenever `fetcher` changes (memoise it with
 * useCallback over its inputs). A superseded request is aborted, so a slow
 * response can never overwrite a newer one. `loading` and `error` are derived:
 * a result only counts for the fetcher/reload that produced it, so an error is
 * cleared the moment the next load starts, and no state is set synchronously in
 * the effect. `loading` means a new query, `refreshing` a reload of the same one; `data`
 * keeps the previous result in both cases.
 */
export function useApiData<T>(fetcher: Fetcher<T>, pollMs?: number) {
  const [reloads, setReloads] = useState(0)
  const [settled, setSettled] = useState<Settled<T> | null>(null)

  useEffect(() => {
    const controller = new AbortController()
    fetcher(controller.signal).then(
      data => setSettled({ fetcher, reloads, data, error: null }),
      (error: unknown) => {
        if (isAbortError(error)) return
        const message = errorMessage(error, 'Failed to load')
        // Keep the last good data only when it belongs to this same query.
        setSettled(prev => ({ fetcher, reloads, data: prev?.fetcher === fetcher ? prev.data : null, error: message }))
      },
    )
    return () => controller.abort()
  }, [fetcher, reloads])

  useEffect(() => {
    if (!pollMs) return
    // A background tab has nobody to show the data to, and each open dashboard
    // polls /summary (several aggregate queries), so skip the tick while hidden.
    // visibilitychange also reloads on return, so the page never shows data up to
    // pollMs old.
    const reloadIfVisible = () => {
      if (document.visibilityState === 'visible') setReloads(n => n + 1)
    }
    const id = setInterval(reloadIfVisible, pollMs)
    document.addEventListener('visibilitychange', reloadIfVisible)
    return () => {
      clearInterval(id)
      document.removeEventListener('visibilitychange', reloadIfVisible)
    }
  }, [pollMs])

  const isSameQuery = settled?.fetcher === fetcher
  const isCurrent = isSameQuery && settled.reloads === reloads
  return {
    data: settled?.data ?? null,
    error: isCurrent ? settled.error : null,
    /** First load, or the query changed: show a skeleton. */
    loading: !isSameQuery,
    /** Same query being reloaded (poll or after a mutation): keep showing `data`. */
    refreshing: isSameQuery && !isCurrent,
    reload: () => setReloads(n => n + 1),
  }
}
