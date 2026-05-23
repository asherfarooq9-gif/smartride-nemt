'use client'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import LoadingRows from './LoadingRows'
import React from 'react'

interface Column<T> {
  header: string
  key: string
  render: (row: T) => React.ReactNode
  className?: string
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
    <div className="bg-white border border-blue-100 rounded-2xl shadow-sm overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-blue-50 text-blue-700 text-xs uppercase tracking-wider">
            <tr>
              {columns.map(col => (
                <th
                  key={col.key}
                  className={`px-4 py-3 text-left font-semibold ${col.className ?? ''}`}
                >
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-blue-50">
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
                  className="hover:bg-blue-50/40 transition-colors"
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
        <div className="flex items-center justify-between px-4 py-3 border-t border-blue-50 text-sm text-gray-500">
          <span>Page {page} of {totalPages}</span>
          <div className="flex gap-2">
            <button
              onClick={() => onPageChange(page - 1)}
              disabled={page <= 1}
              className="p-1.5 rounded-lg hover:bg-blue-50 disabled:opacity-30 disabled:cursor-not-allowed transition"
            >
              <ChevronLeft size={16} />
            </button>
            <button
              onClick={() => onPageChange(page + 1)}
              disabled={page >= totalPages}
              className="p-1.5 rounded-lg hover:bg-blue-50 disabled:opacity-30 disabled:cursor-not-allowed transition"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
