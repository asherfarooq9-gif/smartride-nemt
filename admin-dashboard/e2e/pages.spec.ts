import fs from 'node:fs/promises'
import { expect, test } from '@playwright/test'
import { RIDE_ADDRESS, testDriver } from './api'
import { APP_PAGES } from './pages'

for (const { path, heading, ready } of APP_PAGES) {
  test(`${path} loads without failed API calls or console errors`, async ({ page }, testInfo) => {
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
    await expect(ready(page, testInfo.project.name)).toBeVisible()
    expect(failedApi).toEqual([])
    expect(consoleErrors).toEqual([])
  })
}

test('alerts page does not present invented alerts as live incidents', async ({ page }) => {
  await page.goto('/alerts')
  await expect(page.getByText('Alerts are not connected yet')).toBeVisible()
  await expect(page.getByText(/Benazir|Ride #|Low Driver Availability/)).toHaveCount(0)
})

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
  await expect(page.getByRole('button', { name, exact: true })).toBeVisible()
})

test('adding a hospital without required fields shows an inline error, not an alert dialog', async ({ page }) => {
  const dialogs: string[] = []
  page.on('dialog', d => {
    dialogs.push(d.message())
    void d.dismiss()
  })
  await page.goto('/hospitals')
  await page.getByRole('button', { name: 'Add Hospital' }).click()
  await page.getByRole('button', { name: 'Save Hospital' }).click()
  await expect(page.locator('main').getByRole('alert')).toContainText('Name, address and city are required')
  expect(dialogs).toEqual([])
})

test('admin can edit a hospital and toggle it inactive and active again', async ({ page }, testInfo) => {
  const name = `E2E Editable ${testInfo.project.name} ${Date.now()}`
  await page.goto('/hospitals')
  await page.getByRole('button', { name: 'Add Hospital' }).click()
  await page.locator('#new-hospital-name').fill(name)
  await page.locator('#new-hospital-address').fill('2 Edit Road')
  await page.locator('#new-hospital-city').fill('Islamabad')
  await page.getByRole('button', { name: 'Save Hospital' }).click()

  const row = page.getByRole('row', { name: new RegExp(name) })
  await row.getByRole('button', { name, exact: true }).click()
  const dialog = page.getByRole('dialog', { name: 'Hospital Details' })
  await dialog.getByLabel('City', { exact: true }).fill('Rawalpindi')
  await dialog.getByLabel('ED Capacity', { exact: true }).fill('120')
  await dialog.getByRole('button', { name: 'cardiology' }).click()
  await dialog.getByRole('button', { name: 'Save Changes' }).click()
  await expect(row.getByText('Rawalpindi')).toBeVisible()
  await expect(row.getByText('0/120')).toBeVisible()

  await dialog.getByRole('button', { name: 'Deactivate' }).click()
  await page.getByRole('dialog', { name: 'Deactivate hospital' }).getByRole('button', { name: 'Yes, deactivate' }).click()
  await expect(row.getByText('Inactive')).toBeVisible()
  await dialog.getByRole('button', { name: 'Activate' }).click()
  await expect(row.getByText('Active', { exact: true })).toBeVisible()
})

test('rides pagination moves between pages with labelled controls', async ({ page }) => {
  await page.goto('/rides')
  const pagination = page.getByRole('navigation', { name: 'Pagination' })
  await expect(pagination.getByText('Page 1 of 2')).toBeVisible()
  await expect(pagination.getByRole('button', { name: 'Previous page' })).toBeDisabled()
  await pagination.getByRole('button', { name: 'Next page' }).click()
  await expect(pagination.getByText('Page 2 of 2')).toBeVisible()
  await expect(pagination.getByRole('button', { name: 'Next page' })).toBeDisabled()
  await pagination.getByRole('button', { name: 'Previous page' }).click()
  await expect(pagination.getByText('Page 1 of 2')).toBeVisible()
})

test('rides can be exported as a quoted CSV', async ({ page }) => {
  await page.goto('/rides')
  await expect(page.getByText(RIDE_ADDRESS)).toBeVisible()
  const downloadPromise = page.waitForEvent('download')
  await page.getByRole('button', { name: 'Export this page (CSV)' }).click()
  const download = await downloadPromise
  const text = await fs.readFile(await download.path(), 'utf8')
  expect(text).toContain('"ID","Type","Status","Pickup","Requested","Completed"')
  expect(text).toContain(`"${RIDE_ADDRESS}"`)
})
