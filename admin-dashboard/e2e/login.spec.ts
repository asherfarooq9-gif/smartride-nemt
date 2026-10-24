import { expect, test } from '@playwright/test'
import { ADMIN, API_URL, TEST_PATIENT } from './api'

test.use({ storageState: { cookies: [], origins: [] } })

test('unauthenticated visit redirects to the login page', async ({ page }) => {
  await page.goto('/rides')
  await expect(page).toHaveURL(/\/login$/)
})

test('unauthenticated visit never renders protected UI or calls the API', async ({ page, request }) => {
  // Record, from the first paint on, whether the app chrome or any API call appears.
  const apiRequests: string[] = []
  page.on('request', r => {
    if (r.url().startsWith(API_URL)) apiRequests.push(r.url())
  })
  await page.addInitScript(() => {
    const w = window as unknown as { __sawProtected: boolean }
    w.__sawProtected = false
    const check = () => {
      if (document.querySelector('aside, main')) w.__sawProtected = true
    }
    new MutationObserver(check).observe(document, { childList: true, subtree: true })
  })

  await page.goto('/rides')
  await expect(page).toHaveURL(/\/login$/)
  await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible()
  expect(await page.evaluate(() => (window as unknown as { __sawProtected: boolean }).__sawProtected)).toBe(false)
  expect(apiRequests).toEqual([])

  // The server-rendered HTML itself carries no protected markup either.
  const html = await (await request.get('/rides')).text()
  expect(html).not.toContain('NEMT Admin')
  expect(html).not.toContain('Total Rides')
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
