import { expect, test } from '@playwright/test'
import { ADMIN } from './api'

test.describe('session handling', () => {
  test('an expired session sends you to login and says why', async ({ page }) => {
    await page.route('**/api/v1/analytics/summary', route =>
      route.fulfill({ status: 401, contentType: 'application/json', body: '{"detail":"Invalid or expired token"}' }),
    )

    await page.goto('/')

    await expect(page).toHaveURL(/\/login$/)
    await expect(page.getByRole('status').filter({ hasText: 'session expired' })).toBeVisible()
  })

  test('the expiry notice is shown once, not on every later visit to login', async ({ page }) => {
    await page.route('**/api/v1/analytics/summary', route =>
      route.fulfill({ status: 401, contentType: 'application/json', body: '{}' }),
    )
    await page.goto('/')
    await expect(page.getByRole('status').filter({ hasText: 'session expired' })).toBeVisible()

    await page.reload()

    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible()
    await expect(page.getByRole('status').filter({ hasText: 'session expired' })).toHaveCount(0)
  })

  test('opening login while already signed in goes to the dashboard', async ({ page }) => {
    await page.goto('/login')

    await expect(page).toHaveURL(/\/$/)
  })
})

test.describe('signed out', () => {
  test.use({ storageState: { cookies: [], origins: [] } })

  test('a non-admin who signs in is signed out of the server too', async ({ page }) => {
    const token = 'patient-token-123'
    await page.route('**/api/v1/auth/login', route =>
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ access_token: token, role: 'patient' }) }),
    )
    const logouts: (string | undefined)[] = []
    await page.route('**/api/v1/auth/logout', route => {
      logouts.push(route.request().headers()['authorization'])
      return route.fulfill({ status: 204 })
    })

    await page.goto('/login')
    await page.getByLabel('Phone').fill('+923001110001')
    await page.getByLabel('Password').fill('patient123')
    await page.getByRole('button', { name: 'Sign in' }).click()

    await expect(page.getByRole('alert').filter({ hasText: 'Admin access only' })).toBeVisible()
    await expect.poll(() => logouts).toEqual([`Bearer ${token}`])
    expect(await page.evaluate(() => localStorage.getItem('sr_token'))).toBeNull()
  })

  test('a failed sign-in attempt does not sign out the session another tab holds', async ({ page }) => {
    await page.goto('/login')
    await page.evaluate(() => localStorage.setItem('sr_token', 'existing-session'))
    await page.route('**/api/v1/auth/login', route =>
      route.fulfill({ status: 401, contentType: 'application/json', body: '{"detail":"Invalid credentials"}' }),
    )

    await page.getByLabel('Phone').fill(ADMIN.phone)
    await page.getByLabel('Password').fill('wrong-password')
    await page.getByRole('button', { name: 'Sign in' }).click()
    await expect(page.getByRole('alert').filter({ hasText: 'Invalid credentials' })).toBeVisible()

    expect(await page.evaluate(() => localStorage.getItem('sr_token'))).toBe('existing-session')
  })
})
