import AxeBuilder from '@axe-core/playwright'
import { expect, test } from '@playwright/test'
import { APP_PAGES } from './pages'

// Impacts that fail the build. Nothing is allow-listed: a violation is fixed, not hidden.
const GATED_IMPACTS = ['critical', 'serious']

type Violation = Awaited<ReturnType<AxeBuilder['analyze']>>['violations'][number]

function gated(violations: Violation[]): string[] {
  return violations
    .filter(v => GATED_IMPACTS.includes(v.impact ?? ''))
    .map(v => `${v.id} (${v.impact}): ${v.nodes.map(n => n.target.join(' ')).join(' | ')}`)
}

for (const { path, ready } of APP_PAGES) {
  test(`${path} has no horizontal page overflow`, async ({ page }, testInfo) => {
    await page.goto(path)
    await expect(ready(page, testInfo.project.name)).toBeVisible()
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    )
    expect(overflow).toBeLessThanOrEqual(0)
  })

  test(`${path} has no critical or serious accessibility violations`, async ({ page }, testInfo) => {
    await page.goto(path)
    await expect(ready(page, testInfo.project.name)).toBeVisible()
    const { violations } = await new AxeBuilder({ page }).analyze()
    await testInfo.attach('axe-violations.json', {
      body: JSON.stringify(
        violations.map(v => ({ id: v.id, impact: v.impact, help: v.help, nodes: v.nodes.length })),
        null,
        2,
      ),
      contentType: 'application/json',
    })
    expect(gated(violations)).toEqual([])
  })
}

test.describe('signed out', () => {
  test.use({ storageState: { cookies: [], origins: [] } })

  test('login page has no critical or serious accessibility violations', async ({ page }) => {
    await page.goto('/login')
    await expect(page.getByRole('button', { name: 'Sign in' })).toBeVisible()
    const { violations } = await new AxeBuilder({ page }).analyze()
    expect(gated(violations)).toEqual([])
  })
})
