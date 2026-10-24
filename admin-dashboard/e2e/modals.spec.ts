import { expect, test } from '@playwright/test'
import { RIDE_ADDRESS } from './api'

test('modal keeps focus inside, closes on Escape and restores focus to the trigger', async ({ page }) => {
  await page.goto('/rides')
  const trigger = page.getByRole('row', { name: new RegExp(RIDE_ADDRESS) }).getByRole('button', { name: /Detail/ })
  await trigger.focus()
  await page.keyboard.press('Enter')

  const detail = page.getByRole('dialog', { name: 'Ride Details' })
  await expect(detail.getByText('Requested')).toBeVisible()
  await expect(detail.getByRole('button', { name: 'Close' })).toBeFocused()

  // Tab repeatedly: focus may only be in the dialog or hand over to browser chrome
  // (body), never on the inert page behind it.
  for (let i = 0; i < 8; i++) {
    await page.keyboard.press('Tab')
    const isContained = await page.evaluate(
      () => document.activeElement === document.body || document.activeElement?.closest('dialog') != null,
    )
    expect(isContained).toBe(true)
  }

  await page.keyboard.press('Escape')
  await expect(detail).toBeHidden()
  await expect(trigger).toBeFocused()
})

test('Escape closes only the top-most of two stacked modals', async ({ page }) => {
  await page.goto('/rides')
  await page.getByRole('row', { name: new RegExp(RIDE_ADDRESS) }).getByRole('button', { name: /Detail/ }).click()
  const detail = page.getByRole('dialog', { name: 'Ride Details' })
  await detail.getByRole('button', { name: 'Cancel Ride' }).click()
  const confirm = page.getByRole('dialog', { name: 'Cancel Ride' })
  await expect(confirm).toBeVisible()

  await page.keyboard.press('Escape')
  await expect(confirm).toBeHidden()
  await expect(detail).toBeVisible()

  await page.keyboard.press('Escape')
  await expect(detail).toBeHidden()
})
