import { defineConfig } from '@playwright/test';
import base from './playwright.config';

export default defineConfig({
  ...base,
  testMatch: '**/ui-stutter.spec.ts',
  retries: 0,
  workers: 1,
  use: {
    ...base.use,
    browserName: 'chromium',
    actionTimeout: 15_000,
    reducedMotion: 'no-preference',
    permissions: ['geolocation'],
    geolocation: { latitude: 48.137154, longitude: 11.576124, accuracy: 10 },
    // Recording itself distorts the frame gaps being measured.
    trace: 'off',
    video: 'off',
    screenshot: 'off',
  },
});
