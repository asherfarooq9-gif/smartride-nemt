import { useEffect, useRef, useState } from 'react'

const SEARCH_DEBOUNCE_MS = 400

/**
 * A search box value plus its debounced counterpart. When the debounced value
 * settles on a new value, `setPage` (a state setter, so stable) is reset to page 1.
 * An unchanged value never resets the page, so the first timer after load cannot undo a quick page change.
 */
export function useDebouncedSearch(setPage: (page: number) => void) {
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState('')
  const settled = useRef('')

  useEffect(() => {
    const timer = setTimeout(() => {
      if (settled.current === searchInput) return
      settled.current = searchInput
      setSearch(searchInput)
      setPage(1)
    }, SEARCH_DEBOUNCE_MS)
    return () => clearTimeout(timer)
  }, [searchInput, setPage])

  return { searchInput, setSearchInput, search }
}
