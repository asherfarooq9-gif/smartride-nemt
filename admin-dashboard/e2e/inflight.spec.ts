import { expect, test } from '@playwright/test'
import { testDriver } from './api'

test('a second click on another row does not release the first row while it is still in flight', async ({ page }, testInfo) => {
  const project = testInfo.project.name
  const first = testDriver(project).full_name
  const second = testDriver(project, true).full_name
  const rowFor = (name: string) => page.getByRole('row', { name: new RegExp(name) })
  const actionOf = (name: string) => rowFor(name).getByRole('button', { name: /Verify|Revoke|…/ })

  // Show every driver as unverified so the button is "Verify" (no confirmation step)
  // whatever earlier tests did to the real rows. Nothing is written to the database.
  await page.route('**/api/v1/drivers?*', async route => {
    try {
      const response = await route.fetch()
      const body = await response.json()
      body.items = body.items.map((d: object) => ({ ...d, is_verified: false }))
      await route.fulfill({ response, json: body })
    } catch {
      // The test finished and the page closed while this request was in flight.
    }
  })

  let releaseFirst!: () => void
  const firstCanFinish = new Promise<void>(resolve => (releaseFirst = resolve))
  let calls = 0
  await page.route('**/api/v1/drivers/*/verify', async route => {
    calls += 1
    if (calls === 1) await firstCanFinish // hold the first request open
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' })
  })

  await page.goto('/drivers')
  await expect(rowFor(first)).toBeVisible()
  await expect(rowFor(second)).toBeVisible()

  await actionOf(first).click()
  await expect(actionOf(first)).toBeDisabled()

  await actionOf(second).click() // answered at once; the first is still pending
  await expect.poll(() => calls).toBe(2)
  await page.waitForTimeout(300) // let the second request finish and clear its state

  await expect(actionOf(first)).toBeDisabled() // it must not have been released by the second

  releaseFirst()
  await expect(actionOf(first)).toBeEnabled()
})
