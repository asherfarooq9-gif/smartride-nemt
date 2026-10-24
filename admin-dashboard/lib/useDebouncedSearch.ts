import { useEffect, useState } from 'react'

const SEARCH_DEBOUNCE_MS = 400

/**
 * A search box value plus its debounced counterpart. When the debounced value
 * settles, `setPage` (a state setter, so stable) is reset to page 1.
 */
export function useDebouncedSearch(setPage: (page: number) => void) {
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState('')

  useEffect(() => {
    const timer = setTimeout(() => {
      setSearch(searchInput)
      setPage(1)
    }, SEARCH_DEBOUNCE_MS)
    return () => clearTimeout(timer)
  }, [searchInput, setPage])

  return { searchInput, setSearchInput, search }
}
