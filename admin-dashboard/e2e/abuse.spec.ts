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

test('double-clicking an action is harmless', async ({ page }, testInfo) => {
  const driver = testDriver(testInfo.project.name, true)
  await page.goto('/drivers')
  const row = page.getByRole('row', { name: new RegExp(driver.full_name) })
  const button = row.getByRole('button', { name: /Verify|Revoke/ })
  await button.dblclick()
  await expect(row.getByRole('button', { name: /Verify|Revoke/ })).toBeEnabled()
  await expect(page.locator('.text-red-600')).toHaveCount(0)
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

test('the keyboard alone can sign in', async ({ browser }) => {
  const context = await browser.newContext({ storageState: { cookies: [], origins: [] } })
  const page = await context.newPage()
  await page.goto('http://localhost:13100/login')
  await page.keyboard.press('Tab')
  await page.keyboard.type(ADMIN.phone)
  await page.keyboard.press('Tab')
  await page.keyboard.type(ADMIN.password)
  await page.keyboard.press('Enter')
  await expect(page).toHaveURL(/\/$/)
  await context.close()
})
