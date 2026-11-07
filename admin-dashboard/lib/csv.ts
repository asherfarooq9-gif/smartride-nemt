export type CsvValue = string | number | null | undefined

// A cell starting with one of these is evaluated as a formula by Excel/Sheets.
const FORMULA_PREFIX = /^[=+\-@\t\r]/

/** Quote one cell, double embedded quotes and neutralise spreadsheet formulas. */
export function escapeCsvCell(value: CsvValue): string {
  let text = value == null ? '' : String(value)
  if (typeof value === 'string' && FORMULA_PREFIX.test(text)) text = `'${text}`
  return `"${text.replace(/"/g, '""')}"`
}

export function toCsv(header: string[], rows: CsvValue[][]): string {
  return [header, ...rows].map(row => row.map(escapeCsvCell).join(',')).join('\r\n') + '\r\n'
}

export function downloadCsv(filename: string, csv: string) {
  // The BOM lets Excel read non-ASCII (e.g. Urdu) addresses as UTF-8.
  const blob = new Blob(['\uFEFF', csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  // Attached while clicked (some browsers ignore a detached link), and the URL is
  // released later: revoking it straight after click() can cancel the download.
  document.body.appendChild(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
