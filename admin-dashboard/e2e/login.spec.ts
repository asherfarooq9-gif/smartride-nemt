import { expect, test } from '@playwright/test'
import { ADMIN, TEST_PATIENT } from './api'

test.use({ storageState: { cookies: [], origins: [] } })

test('unauthenticated visit redirects to the login page', async ({ page }) => {
  await page.goto('/rides')
  await expect(page).toHaveURL(/\/login$/)
})

test('wrong password shows an error and stays on the login page', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Phone').fill(ADMIN.phone)
  await page.getByLabel('Password').fill('not-the-password')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.locator('form [role=alert]')).toBeVisible()
  await expect(page).toHaveURL(/\/login$/)
})

test('a non-admin account is rejected', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Phone').fill(TEST_PATIENT.phone)
  await page.getByLabel('Password').fill(TEST_PATIENT.password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.locator('form [role=alert]')).toContainText('Admin access only')
  expect(await page.evaluate(() => localStorage.getItem('sr_token'))).toBeNull()
})

test('admin can sign in and reach the dashboard', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Phone').fill(ADMIN.phone)
  await page.getByLabel('Password').fill(ADMIN.password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page).toHaveURL(/\/$/)
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
})

test('an expired or invalid token sends the user back to login', async ({ page }) => {
  await page.goto('/login')
  await page.evaluate(() => localStorage.setItem('sr_token', 'not-a-valid-token'))
  await page.goto('/')
  await expect(page).toHaveURL(/\/login$/)
  expect(await page.evaluate(() => localStorage.getItem('sr_token'))).toBeNull()
})
