import type { Locator, Page } from '@playwright/test'
import { RIDE_ADDRESS, TEST_PATIENT, testDriver } from './api'

interface AppPage {
  path: string
  heading: string | RegExp
  /** Content that only exists once the page's data has loaded. */
  ready: (page: Page, project: string) => Locator
}

export const APP_PAGES: AppPage[] = [
  { path: '/', heading: 'Dashboard', ready: p => p.getByText('Total Rides') },
  { path: '/rides', heading: /^Rides/, ready: p => p.getByText(RIDE_ADDRESS) },
  { path: '/drivers', heading: /^Drivers/, ready: (p, project) => p.getByRole('button', { name: testDriver(project).full_name }) },
  { path: '/patients', heading: /^Patients/, ready: p => p.getByRole('button', { name: TEST_PATIENT.full_name, exact: true }) },
  { path: '/hospitals', heading: /^Hospitals/, ready: p => p.locator('tbody tr:not(.animate-pulse)').first() },
  { path: '/analytics', heading: /Analytics/, ready: p => p.getByText(/Peak Predicted|No data yet/).first() },
  { path: '/alerts', heading: /Alerts/, ready: p => p.getByText('Alerts are not connected yet') },
]
