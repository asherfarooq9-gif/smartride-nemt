import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import StatusBadge from './StatusBadge'

describe('StatusBadge', () => {
  it('humanizes the status value by replacing underscores', () => {
    render(<StatusBadge value="driver_assigned" type="ride" />)
    expect(screen.getByText('driver assigned')).toBeInTheDocument()
  })

  it('applies the ride status color class for a known ride status', () => {
    render(<StatusBadge value="completed" type="ride" />)
    const badge = screen.getByText('completed')
    expect(badge.className).toContain('text-green-800')
  })

  it('applies the driver status color class for a known driver status', () => {
    render(<StatusBadge value="available" type="driver" />)
    const badge = screen.getByText('available')
    expect(badge.className).toContain('text-green-800')
  })

  it('falls back to gray styling for an unknown value', () => {
    render(<StatusBadge value="nonsense" type="ride" />)
    const badge = screen.getByText('nonsense')
    expect(badge.className).toContain('text-gray-600')
  })
})
