import AxeBuilder from '@axe-core/playwright'
import { expect, test } from '@playwright/test'

const PAGES = ['/', '/rides', '/drivers', '/patients', '/hospitals', '/analytics', '/alerts']

for (const path of PAGES) {
  test(`${path} has no horizontal page overflow`, async ({ page }) => {
    await page.goto(path)
    await page.waitForLoadState('networkidle')
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    )
    expect(overflow).toBeLessThanOrEqual(0)
  })

  test(`${path} has no critical accessibility violations`, async ({ page }, testInfo) => {
    await page.goto(path)
    await page.waitForLoadState('networkidle')
    const { violations } = await new AxeBuilder({ page }).analyze()
    // Serious/moderate findings are recorded for the audit report, not gated yet.
    await testInfo.attach('axe-violations.json', {
      body: JSON.stringify(
        violations.map(v => ({ id: v.id, impact: v.impact, help: v.help, nodes: v.nodes.length })),
        null,
        2,
      ),
      contentType: 'application/json',
    })
    expect(violations.filter(v => v.impact === 'critical').map(v => v.id)).toEqual([])
  })
}

test('login page has no critical accessibility violations', async ({ browser }) => {
  const context = await browser.newContext({ storageState: { cookies: [], origins: [] } })
  const page = await context.newPage()
  await page.goto('http://localhost:13100/login')
  const { violations } = await new AxeBuilder({ page }).analyze()
  expect(violations.filter(v => v.impact === 'critical').map(v => v.id)).toEqual([])
  await context.close()
})
