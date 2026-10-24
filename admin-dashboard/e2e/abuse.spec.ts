import { expect, test } from '@playwright/test'
import { ADMIN, API_URL, testDriver } from './api'

test('pages are served with hardening headers', async ({ page }) => {
  const response = await page.goto('/login')
  const headers = response!.headers()
  expect(headers['content-security-policy']).toContain("frame-ancestors 'none'")
  expect(headers['content-security-policy']).toContain("object-src 'none'")
  expect(headers['x-frame-options']).toBe('DENY')
  expect(headers['x-content-type-options']).toBe('nosniff')
  expect(headers['x-powered-by']).toBeUndefined()
})

test('the CSP allows scripts only through a fresh per-request nonce', async ({ page }) => {
  const scriptSrc = async () => {
    const response = await page.goto('/login')
    const csp = response!.headers()['content-security-policy']
    return csp.split(';').map(d => d.trim()).find(d => d.startsWith('script-src '))!
  }
  const first = await scriptSrc()
  const second = await scriptSrc()
  expect(first).toMatch(/'nonce-[A-Za-z0-9+/=]+'/)
  expect(first).not.toContain("'unsafe-inline'")
  expect(first).not.toBe(second)
  // The nonce must actually reach Next's inline scripts, or the page would not hydrate.
  await expect(page.getByRole('button', { name: 'Sign in' })).toBeEnabled()
})

test('script injected through a hospital name is shown as text and never runs', async ({ page }) => {
  const dialogs: string[] = []
  page.on('dialog', d => {
    dialogs.push(d.message())
    void d.dismiss()
  })
  const payload = `<img src=x onerror=alert(1)><script>alert(2)</script>`

  await page.goto('/hospitals')
  await page.getByRole('button', { name: 'Add Hospital' }).click()
  await page.locator('#new-hospital-name').fill(payload)
  await page.locator('#new-hospital-address').fill('1 Test Road')
  await page.locator('#new-hospital-city').fill('Islamabad')
  await page.locator('#new-hospital-lat').fill('33.7')
  await page.locator('#new-hospital-lng').fill('73.0')
  await page.getByRole('button', { name: 'Save Hospital' }).click()

  await expect(page.getByText(payload, { exact: false }).first()).toBeVisible()
  await page.reload()
  await expect(page.getByText(payload, { exact: false }).first()).toBeVisible()
  expect(dialogs).toEqual([])
  expect(await page.locator('img[src="x"]').count()).toBe(0)
})

test('double-clicking an action sends one request and is harmless', async ({ page }, testInfo) => {
  const driver = testDriver(testInfo.project.name, true)
  const verifyRequests: string[] = []
  page.on('request', r => {
    if (r.method() === 'PATCH' && r.url().includes('/verify')) verifyRequests.push(r.url())
  })
  await page.goto('/drivers')
  const row = page.getByRole('row', { name: new RegExp(driver.full_name) })
  await row.getByRole('button', { name: /Verify|Revoke/ }).dblclick()
  await expect(row.getByText('Verified')).toBeVisible()
  await expect(row.getByRole('button', { name: 'Revoke' })).toBeEnabled()
  expect(verifyRequests).toHaveLength(1)
  await expect(page.locator('main').getByRole('alert')).toHaveCount(0)
})

test('after signing out the back button cannot reveal data', async ({ page, request }) => {
  // Own session: signing out revokes the token, which must not be the shared one.
  const login = await request.post(`${API_URL}/api/v1/auth/login`, {
    data: { phone: ADMIN.phone, password: ADMIN.password },
  })
  const { access_token } = await login.json()
  await page.goto('/login')
  await page.evaluate(t => localStorage.setItem('sr_token', t), access_token)

  await page.goto('/rides')
  await page.goto('/')
  await page.getByRole('button', { name: 'Toggle sidebar' }).click()
  await page.getByRole('button', { name: /sign out|logout/i }).click()
  await expect(page).toHaveURL(/\/login$/)

  await page.goBack()
  await expect(page).toHaveURL(/\/login$/)
  expect(await page.evaluate(() => localStorage.getItem('sr_token'))).toBeNull()
})

test('a revoked session is sent to login on the next request', async ({ page, request }) => {
  // Mint a second session, revoke it server-side, then use it in the browser.
  const login = await request.post(`${API_URL}/api/v1/auth/login`, {
    data: { phone: ADMIN.phone, password: ADMIN.password },
  })
  const { access_token } = await login.json()
  await request.post(`${API_URL}/api/v1/auth/logout`, {
    headers: { Authorization: `Bearer ${access_token}` },
  })

  await page.goto('/login')
  await page.evaluate(t => localStorage.setItem('sr_token', t), access_token)
  await page.goto('/rides')
  await expect(page).toHaveURL(/\/login$/)
})

test.describe('signed out', () => {
  test.use({ storageState: { cookies: [], origins: [] } })

  test('the keyboard alone can sign in', async ({ page }) => {
    await page.goto('/login')
    await page.keyboard.press('Tab')
    await page.keyboard.type(ADMIN.phone)
    await page.keyboard.press('Tab')
    await page.keyboard.type(ADMIN.password)
    await page.keyboard.press('Enter')
    await expect(page).toHaveURL(/\/$/)
  })
})
