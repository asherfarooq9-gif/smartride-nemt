import { expect, test } from '@playwright/test'
import { RIDE_ADDRESS, cancelRideAddress } from './api'

test('admin can cancel a ride after confirming', async ({ page }, testInfo) => {
  const address = cancelRideAddress(testInfo.project.name)
  await page.goto('/rides')
  const row = page.getByRole('row', { name: new RegExp(address) })
  await row.getByRole('button', { name: /Detail/ }).click()

  const detail = page.getByRole('dialog', { name: 'Ride Details' })
  await detail.getByRole('button', { name: 'Cancel Ride' }).click()
  const confirm = page.getByRole('dialog', { name: 'Cancel Ride' })
  await confirm.getByRole('button', { name: 'Yes, cancel' }).click()

  await expect(detail).toBeHidden()
  await expect(row.getByText('cancelled')).toBeVisible()
})

test('a failed cancel shows the server error with its trace id inside the dialog', async ({ page }) => {
  await page.route('**/api/v1/rides/*/status', route =>
    route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({ detail: 'Internal server error', code: 'internal_error', trace_id: 'trace-abc-123' }),
    }),
  )
  await page.goto('/rides')
  await page.getByRole('row', { name: new RegExp(RIDE_ADDRESS) }).getByRole('button', { name: /Detail/ }).click()
  const detail = page.getByRole('dialog', { name: 'Ride Details' })
  await detail.getByRole('button', { name: 'Cancel Ride' }).click()
  await page.getByRole('dialog', { name: 'Cancel Ride' }).getByRole('button', { name: 'Yes, cancel' }).click()
  await expect(detail.getByRole('alert')).toContainText('Internal server error (reference trace-abc-123)')
})

test('a ride detail that fails to load shows an inline error that can be retried', async ({ page }) => {
  let failuresLeft = 1
  await page.route('**/api/v1/rides/*/detail', route => {
    if (failuresLeft-- > 0) {
      return route.fulfill({
        status: 422,
        contentType: 'application/json',
        body: JSON.stringify({ detail: [{ msg: 'bad id' }, { msg: 'second problem' }] }),
      })
    }
    return route.continue()
  })
  await page.goto('/rides')
  await page.getByRole('row', { name: new RegExp(RIDE_ADDRESS) }).getByRole('button', { name: /Detail/ }).click()
  const detail = page.getByRole('dialog', { name: 'Ride Details' })
  await expect(detail.getByRole('alert')).toContainText('bad id; second problem')
  await detail.getByRole('button', { name: 'Try again' }).click()
  await expect(detail.getByText('Requested')).toBeVisible()
  await expect(detail.getByRole('alert')).toHaveCount(0)
})
