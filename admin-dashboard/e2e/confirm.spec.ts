import { expect, test, type Page } from '@playwright/test'
import { testDriver } from './api'

/** Lists every driver as verified without touching the database, and counts PATCHes. */
async function mockVerifiedDrivers(page: Page): Promise<{ patches: () => number }> {
  let patches = 0
  await page.route('**/api/v1/drivers?*', async route => {
    try {
      const response = await route.fetch()
      const body = await response.json()
      body.items = body.items.map((d: object) => ({ ...d, is_verified: true }))
      await route.fulfill({ response, json: body })
    } catch {
      // The test finished and the page closed while this request was in flight.
    }
  })
  await page.route('**/api/v1/drivers/*/verify', async route => {
    patches += 1
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' })
  })
  return { patches: () => patches }
}

test('revoking a driver asks first, and keeping them changes nothing', async ({ page }, testInfo) => {
  const { patches } = await mockVerifiedDrivers(page)
  await page.goto('/drivers')
  const row = page.getByRole('row', { name: new RegExp(testDriver(testInfo.project.name).full_name) })

  await row.getByRole('button', { name: 'Revoke' }).click()
  const dialog = page.getByRole('dialog', { name: 'Revoke verification' })
  await expect(dialog).toBeVisible()
  await expect(dialog.getByRole('button', { name: 'Keep verified' })).toBeFocused()
  expect(patches()).toBe(0)

  await dialog.getByRole('button', { name: 'Keep verified' }).click()
  await expect(dialog).toBeHidden()
  expect(patches()).toBe(0)
})

test('confirming the revoke sends exactly one request', async ({ page }, testInfo) => {
  const { patches } = await mockVerifiedDrivers(page)
  await page.goto('/drivers')
  const row = page.getByRole('row', { name: new RegExp(testDriver(testInfo.project.name).full_name) })

  await row.getByRole('button', { name: 'Revoke' }).click()
  await page.getByRole('dialog', { name: 'Revoke verification' }).getByRole('button', { name: 'Yes, revoke' }).click()

  await expect.poll(patches).toBe(1)
})

test('dragging a text selection out of a dialog and over the backdrop does not close it', async ({ page }, testInfo) => {
  const name = `E2E Drag ${testInfo.project.name} ${Date.now()}`
  await page.goto('/hospitals')
  await page.getByRole('button', { name: 'Add Hospital' }).click()
  await page.locator('#new-hospital-name').fill(name)
  await page.locator('#new-hospital-address').fill('3 Drag Road')
  await page.locator('#new-hospital-city').fill('Islamabad')
  await page.getByRole('button', { name: 'Save Hospital' }).click()
  await page.getByRole('row', { name: new RegExp(name) }).getByRole('button', { name, exact: true }).click()

  const dialog = page.getByRole('dialog', { name: 'Hospital Details' })
  const city = dialog.getByLabel('City', { exact: true })
  await city.fill('Unsaved city')
  const box = (await city.boundingBox())!

  // Press inside the input, release over the backdrop outside the dialog.
  await page.mouse.move(box.x + 10, box.y + box.height / 2)
  await page.mouse.down()
  await page.mouse.move(2, 2)
  await page.mouse.up()

  await expect(dialog).toBeVisible()
  await expect(city).toHaveValue('Unsaved city')
})

test('a press that starts and ends on the backdrop still closes the dialog', async ({ page }, testInfo) => {
  const name = `E2E Backdrop ${testInfo.project.name} ${Date.now()}`
  await page.goto('/hospitals')
  await page.getByRole('button', { name: 'Add Hospital' }).click()
  await page.locator('#new-hospital-name').fill(name)
  await page.locator('#new-hospital-address').fill('4 Backdrop Road')
  await page.locator('#new-hospital-city').fill('Islamabad')
  await page.getByRole('button', { name: 'Save Hospital' }).click()
  await page.getByRole('row', { name: new RegExp(name) }).getByRole('button', { name, exact: true }).click()
  const dialog = page.getByRole('dialog', { name: 'Hospital Details' })
  await expect(dialog).toBeVisible()

  await page.mouse.click(2, 2)

  await expect(dialog).toBeHidden()
})
