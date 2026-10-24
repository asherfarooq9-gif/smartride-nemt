import { expect, test } from '@playwright/test'
import { escapeCsvCell, toCsv } from '../lib/csv'

// Pure unit tests: they never use the page, so the viewport projects add nothing.
test.describe('csv escaping', () => {
  test('quotes every cell and doubles embedded quotes', () => {
    expect(escapeCsvCell('plain')).toBe('"plain"')
    expect(escapeCsvCell('say "hi"')).toBe('"say ""hi"""')
  })

  test('keeps commas and newlines inside one quoted cell', () => {
    expect(escapeCsvCell('a,b\nc')).toBe('"a,b\nc"')
  })

  test('renders null and undefined as empty cells', () => {
    expect(escapeCsvCell(null)).toBe('""')
    expect(escapeCsvCell(undefined)).toBe('""')
  })

  test('neutralises formula injection in text cells', () => {
    for (const prefix of ['=', '+', '-', '@', '\t', '\r']) {
      expect(escapeCsvCell(`${prefix}CMD()`)).toBe(`"'${prefix}CMD()"`)
    }
  })

  test('leaves real numbers untouched, including negatives', () => {
    expect(escapeCsvCell(-3.5)).toBe('"-3.5"')
  })

  test('joins header and rows with CRLF', () => {
    expect(toCsv(['A', 'B'], [['1', '=2']])).toBe('"A","B"\r\n"1","\'=2"\r\n')
  })
})
