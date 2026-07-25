import { describe, it, expect, beforeEach } from 'vitest'
import { getToken, setToken, clearToken } from './api'

describe('token storage helpers', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('returns null when no token is stored', () => {
    expect(getToken()).toBeNull()
  })

  it('persists and reads back a token', () => {
    setToken('abc123')
    expect(getToken()).toBe('abc123')
  })

  it('clears a stored token', () => {
    setToken('abc123')
    clearToken()
    expect(getToken()).toBeNull()
  })
})
