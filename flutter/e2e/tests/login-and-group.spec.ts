import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';

import { dataPath } from '../test-data-path.js';

type E2eData = {
  username: string;
  password: string;
  groupName: string;
};

function readE2eData(): E2eData {
  return JSON.parse(readFileSync(dataPath(), 'utf8')) as E2eData;
}

test('logs in and renders the seeded group', async ({ page }) => {
  const data = readE2eData();

  await page.goto('/');
  await page.waitForFunction(
    () => document.querySelector('#splash-screen') === null,
    undefined,
    { timeout: 30_000 },
  );

  const accessibilityPlaceholder = page.locator('flt-semantics-placeholder');
  await accessibilityPlaceholder.waitFor({ state: 'attached', timeout: 15_000 });
  await page.waitForTimeout(500);
  await accessibilityPlaceholder.focus();
  await page.keyboard.press('Enter');

  await page.locator('input[aria-label="Name"]').fill(data.username);
  await page.locator('input[aria-label="Password"]').fill(data.password);
  await page
    .locator('flt-semantics[role="button"]')
    .filter({ hasText: /^LOGIN$/ })
    .click();

  await page.waitForURL(/#\/home/, { timeout: 30_000 });
  await page.locator('[role="tab"][aria-label="Groups"]').click();
  await expect(page.locator('body')).toContainText('Your groups', { timeout: 30_000 });
  await expect(page.locator('body')).toContainText(data.groupName, { timeout: 30_000 });
});
