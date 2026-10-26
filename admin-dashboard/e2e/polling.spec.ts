import { expect, test } from '@playwright/test'

declare global {
  interface Window {
    __setHidden: (hidden: boolean) => void
  }
}

test('a hidden tab stops polling and catches up as soon as it is visible again', async ({ page }) => {
  let summaryCalls = 0
  page.on('request', r => {
    if (r.url().includes('/api/v1/analytics/summary')) summaryCalls++
  })
  await page.clock.install()
  await page.addInitScript(() => {
    let hidden = false
    Object.defineProperty(document, 'visibilityState', { get: () => (hidden ? 'hidden' : 'visible') })
    window.__setHidden = (value: boolean) => {
      hidden = value
      document.dispatchEvent(new Event('visibilitychange'))
    }
  })
  await page.goto('/')
  await expect(page.getByText('Total Rides')).toBeVisible()
  const afterFirstLoad = summaryCalls

  await page.evaluate(() => window.__setHidden(true))
  await page.clock.runFor(95_000) // runs all three 30 s poll ticks that fall due while hidden
  await page.waitForTimeout(500) // real time: let any request those ticks started reach the network
  expect(summaryCalls).toBe(afterFirstLoad)

  await page.evaluate(() => window.__setHidden(false))
  await expect.poll(() => summaryCalls).toBeGreaterThan(afterFirstLoad)
})
