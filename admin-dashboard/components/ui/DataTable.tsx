'use client'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import LoadingRows from './LoadingRows'
import React from 'react'

interface Column<T> {
  header: string
  key: string
  render: (row: T) => React.ReactNode
  className?: string
  /** Visually hide the header text (e.g. an actions column) but keep it for screen readers. */
  hideHeader?: boolean
}

interface DataTableProps<T> {
  columns: Column<T>[]
  rows: T[]
  keyFn: (row: T) => string
  loading: boolean
  loadingCols?: number
  emptySlot?: React.ReactNode
  page: number
  totalPages: number
  onPageChange: (p: number) => void
}

export default function DataTable<T>({
  columns,
  rows,
  keyFn,
  loading,
  loadingCols,
  emptySlot,
  page,
  totalPages,
  onPageChange,
}: DataTableProps<T>) {
  return (
    <div className="bg-panel-raised border border-edge rounded-md  overflow-hidden">
      <div className="relative overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-panel-inset">
            <tr>
              {columns.map(col => (
                <th
                  key={col.key}
                  scope="col"
                  className={`legend px-4 py-3 text-left text-[0.72rem] ${col.className ?? ''}`}
                >
                  <span className={col.hideHeader ? 'sr-only' : undefined}>{col.header}</span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-edge">
            {loading ? (
              <LoadingRows cols={loadingCols ?? columns.length} />
            ) : rows.length === 0 ? (
              emptySlot ? (
                <tr>
                  <td colSpan={columns.length}>{emptySlot}</td>
                </tr>
              ) : null
            ) : (
              rows.map(row => (
                <tr
                  key={keyFn(row)}
                  className="hover:bg-panel-inset transition-colors"
                >
                  {columns.map(col => (
                    <td
                      key={col.key}
                      className={`px-4 py-3 ${col.className ?? ''}`}
                    >
                      {col.render(row)}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <nav aria-label="Pagination" className="flex items-center justify-between px-4 py-3 border-t border-edge text-sm text-ink-dim">
          <span aria-live="polite">Page {page} of {totalPages}</span>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => onPageChange(page - 1)}
              disabled={page <= 1}
              aria-label="Previous page"
              className="p-1.5 rounded hover:bg-panel-inset disabled:opacity-30 disabled:cursor-not-allowed transition"
            >
              <ChevronLeft size={16} aria-hidden="true" />
            </button>
            <button
              type="button"
              onClick={() => onPageChange(page + 1)}
              disabled={page >= totalPages}
              aria-label="Next page"
              className="p-1.5 rounded hover:bg-panel-inset disabled:opacity-30 disabled:cursor-not-allowed transition"
            >
              <ChevronRight size={16} aria-hidden="true" />
            </button>
          </div>
        </nav>
      )}
    </div>
  )
}
