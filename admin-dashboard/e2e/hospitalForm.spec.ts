import { expect, test } from '@playwright/test'
import { EMPTY_FORM, parseHospitalForm, type HospitalFormState } from '../app/hospitals/hospitalForm'

const valid = (over: Partial<HospitalFormState> = {}): HospitalFormState => ({
  ...EMPTY_FORM, name: 'PIMS', address: 'G-8', ...over,
})

test.describe('hospital form validation (no browser)', () => {
  test('a valid form becomes numbers', () => {
    const r = parseHospitalForm(valid({ lat: '33.7', lng: '73.05', ed_capacity: '120' }))
    expect(r).toMatchObject({ ok: true, value: { lat: 33.7, lng: 73.05, ed_capacity: 120 } })
  })

  for (const blank of ['', '   ', '-', '.', 'abc']) {
    test(`latitude "${blank}" is rejected, not turned into 0`, () => {
      expect(parseHospitalForm(valid({ lat: blank })).ok).toBe(false)
    })
    test(`longitude "${blank}" is rejected, not turned into 0`, () => {
      expect(parseHospitalForm(valid({ lng: blank })).ok).toBe(false)
    })
  }

  test('0, 0 is rejected but a real place on one axis is not', () => {
    expect(parseHospitalForm(valid({ lat: '0', lng: '0' }))).toMatchObject({ ok: false })
    expect(parseHospitalForm(valid({ lat: '0', lng: '73' })).ok).toBe(true)
    expect(parseHospitalForm(valid({ lat: '33', lng: '0' })).ok).toBe(true)
  })

  test('out-of-range coordinates are rejected', () => {
    expect(parseHospitalForm(valid({ lat: '91' })).ok).toBe(false)
    expect(parseHospitalForm(valid({ lng: '-181' })).ok).toBe(false)
  })

  for (const capacity of ['', '0', '-5', '2.5', 'x']) {
    test(`ED capacity "${capacity}" is rejected`, () => {
      expect(parseHospitalForm(valid({ ed_capacity: capacity })).ok).toBe(false)
    })
  }

  test('blank name, address or city is rejected', () => {
    for (const key of ['name', 'address', 'city'] as const) {
      expect(parseHospitalForm(valid({ [key]: '  ' })).ok).toBe(false)
    }
  })
})
