import { expect, test } from '@playwright/test';
import type { Page } from '@playwright/test';
import { readFileSync } from 'node:fs';

import { dataPath } from '../test-data-path.js';

type E2eData = {
  username: string;
  password: string;
  groupName: string;
  publicUnjoinedGroupName?: string;
  publicUnjoinedGroupId?: string;
};

function readE2eData(): E2eData {
  return JSON.parse(readFileSync(dataPath(), 'utf8')) as E2eData;
}

test('logs in and renders the seeded group', async ({ page }) => {
  const data = readE2eData();

  await login(page, data);
  await page.locator('[role="tab"][aria-label="Groups"]').click();
  await expect(page.locator('body')).toContainText('Your groups', { timeout: 30_000 });
  await expect(page.locator('body')).toContainText(data.groupName, { timeout: 30_000 });
});

test('loads pins for a public group opened through group search', async ({ page }) => {
  const data = readE2eData();
  const groupName = data.publicUnjoinedGroupName;
  const groupId = data.publicUnjoinedGroupId;
  if (!groupName || !groupId) {
    test.skip(
      true,
      'requires the reusable testdata fixture; source testdata/.env.test before running E2E',
    );
    return;
  }

  await login(page, data);
  await page.locator('[role="tab"][aria-label="Groups"]').click();
  await page.getByRole('button', { name: 'Show menu' }).click();
  await page
    .getByRole('menuitem', { name: 'Search existing groups' })
    .click();

  const searchRequest = page.waitForResponse((response) => {
    const url = new URL(response.url());
    return (
      url.pathname === '/api/v2/groups' &&
      url.searchParams.get('search') === groupName &&
      response.ok()
    );
  });
  await page.locator('input').first().fill(groupName);
  await searchRequest;

  const groupRow = page.getByRole(
    'button',
    { name: new RegExp(escapeRegExp(groupName)) },
  );
  await expect(groupRow).toBeVisible({ timeout: 30_000 });

  const pinsRequest = page.waitForResponse((response) => {
    const url = new URL(response.url());
    return (
      url.pathname === '/api/v2/pins' &&
      url.searchParams.get('groupId') === groupId &&
      response.ok()
    );
  });

  const loadedPinImages = new Set<string>();
  const loadedObjectImages = new Set<string>();
  page.on('response', (response) => {
    const url = new URL(response.url());
    const apiMatch = url.pathname.match(/^\/api\/v2\/pins\/([^/]+)\/image$/);
    if (apiMatch && response.ok()) {
      loadedPinImages.add(apiMatch[1]);
    }
    const objectMatch = url.pathname.match(/^\/monaserver\/pins\/([^/]+)\.png$/);
    if (url.port === '9100' && objectMatch && response.ok()) {
      loadedObjectImages.add(objectMatch[1]);
    }
  });

  await groupRow.click();
  const pinsBody = (await (await pinsRequest).json()) as {
    items?: Array<{ id?: string }>;
  };
  const pinIds = new Set(
    (pinsBody.items ?? []).flatMap((pin) => (pin.id ? [pin.id] : [])),
  );
  expect(pinIds.size).toBeGreaterThan(0);
  await expect(page.getByRole('button', { name: 'Join' })).toBeVisible({
    timeout: 30_000,
  });

  await page.getByRole('tab').nth(1).click();
  await expect
    .poll(
      () => [...pinIds].filter((pinId) => loadedPinImages.has(pinId)).length,
      { timeout: 30_000 },
    )
    .toBe(pinIds.size);
  await expect
    .poll(
      () => [...pinIds].filter((pinId) => loadedObjectImages.has(pinId)).length,
      { timeout: 30_000 },
    )
    .toBe(pinIds.size);
  await expect(
    page.locator('[role="tabpanel"]').last().getByRole('button'),
  ).toHaveCount(pinIds.size);
});

async function login(
  page: Page,
  data: E2eData,
): Promise<void> {
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
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
