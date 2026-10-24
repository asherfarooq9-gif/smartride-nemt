import { defineConfig, devices } from '@playwright/test'
import { ADMIN_URL, API_URL } from './e2e/api'

const python = process.env.E2E_PYTHON ?? 'python'

export default defineConfig({
  testDir: './e2e',
  globalSetup: './e2e/global-setup.ts',
  // One backend and one database: tests share state, so run them serially.
  workers: 1,
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : [['list']],
  use: {
    baseURL: ADMIN_URL,
    storageState: 'e2e/.auth/admin.json',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } } },
    { name: 'tablet', use: { ...devices['Desktop Chrome'], viewport: { width: 768, height: 1024 } } },
    { name: 'mobile', use: { ...devices['Desktop Chrome'], viewport: { width: 375, height: 812 } } },
  ],
  webServer: [
    {
      // Fresh database -> migrations -> seed -> API. See scripts/e2e_backend.py.
      command: `"${python}" ../scripts/e2e_backend.py`,
      url: `${API_URL}/health`,
      timeout: 120_000,
      reuseExistingServer: false,
    },
    {
      command: `npm run build && npm run start -- -p ${new URL(ADMIN_URL).port}`,
      url: ADMIN_URL + '/login',
      timeout: 240_000,
      // A stale server from an earlier run would test old code: reuse only on request
      // (E2E_REUSE_SERVER=1), e.g. when iterating on specs against a fresh build.
      reuseExistingServer: process.env.E2E_REUSE_SERVER === '1',
      env: { NEXT_PUBLIC_API_URL: API_URL },
    },
  ],
})
