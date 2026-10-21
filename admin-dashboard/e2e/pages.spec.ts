import { expect, test } from '@playwright/test'
import { RIDE_ADDRESS, testDriver } from './api'

const PAGES = [
  { path: '/', heading: 'Dashboard' },
  { path: '/rides', heading: /^Rides/ },
  { path: '/drivers', heading: /^Drivers/ },
  { path: '/patients', heading: /^Patients/ },
  { path: '/hospitals', heading: /^Hospitals/ },
  { path: '/analytics', heading: /Analytics/ },
  { path: '/alerts', heading: /Alerts/ },
]

for (const { path, heading } of PAGES) {
  test(`${path} loads without failed API calls or console errors`, async ({ page }) => {
    const failedApi: string[] = []
    const consoleErrors: string[] = []
    page.on('response', r => {
      if (r.url().includes(':18010') && r.status() >= 400) failedApi.push(`${r.status()} ${r.url()}`)
    })
    page.on('console', m => {
      if (m.type() === 'error') consoleErrors.push(m.text())
    })
    await page.goto(path)
    await expect(page.getByRole('heading', { name: heading }).first()).toBeVisible()
    await page.waitForLoadState('networkidle')
    expect(failedApi).toEqual([])
    expect(consoleErrors).toEqual([])
  })
}

test('rides table lists the seeded emergency ride', async ({ page }) => {
  await page.goto('/rides')
  await expect(page.getByText(RIDE_ADDRESS)).toBeVisible()
})

test('admin can verify a pending driver', async ({ page }, testInfo) => {
  await page.goto('/drivers')
  const row = page.getByRole('row', { name: new RegExp(testDriver(testInfo.project.name).full_name) })
  await expect(row.getByText('Pending')).toBeVisible()
  await row.getByRole('button', { name: 'Verify' }).click()
  await expect(row.getByText('Verified')).toBeVisible()
  await expect(row.getByRole('button', { name: 'Revoke' })).toBeVisible()
})

test('admin can add a hospital', async ({ page }) => {
  const name = `E2E Hospital ${Date.now()}`
  await page.goto('/hospitals')
  await page.getByRole('button', { name: 'Add Hospital' }).click()
  await page.locator('#new-hospital-name').fill(name)
  await page.locator('#new-hospital-address').fill('1 Test Road')
  await page.locator('#new-hospital-city').fill('Islamabad')
  await page.locator('#new-hospital-lat').fill('33.7')
  await page.locator('#new-hospital-lng').fill('73.0')
  await page.getByRole('button', { name: 'Save Hospital' }).click()
  await expect(page.getByText(name)).toBeVisible()
})
