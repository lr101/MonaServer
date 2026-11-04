import { defineConfig } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://127.0.0.1:4173';
const width = Number(process.env.E2E_VIEWPORT_WIDTH ?? 450);
const height = Number(process.env.E2E_VIEWPORT_HEIGHT ?? 900);
if (!Number.isInteger(width) || !Number.isInteger(height) || width < 200 || height < 200 || width > 4096 || height > 4096) {
  throw new Error('E2E viewport dimensions must be integers between 200 and 4096');
}
const colorScheme = process.env.E2E_COLOR_SCHEME ?? 'light';
if (colorScheme !== 'light' && colorScheme !== 'dark') {
  throw new Error('E2E_COLOR_SCHEME must be light or dark');
}

export default defineConfig({
  testDir: './tests',
  globalSetup: './global-setup.ts',
  outputDir: process.env.PLAYWRIGHT_OUTPUT_DIR ?? 'test-results',
  fullyParallel: false,
  workers: 1,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  reporter: [['list'], ['html', { outputFolder: process.env.PLAYWRIGHT_REPORT_DIR ?? 'playwright-report', open: 'never' }]],
  use: {
    baseURL,
    viewport: { width, height },
    colorScheme,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  webServer: process.env.PLAYWRIGHT_BASE_URL
    ? undefined
    : {
      command: 'node static_server.mjs',
        url: baseURL,
        reuseExistingServer: !process.env.CI,
        timeout: 120_000,
      },
});
