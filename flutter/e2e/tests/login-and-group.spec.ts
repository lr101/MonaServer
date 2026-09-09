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

const uiErrors = new WeakMap<Page, string[]>();

test.beforeEach(async ({ page }) => {
  const errors: string[] = [];
  uiErrors.set(page, errors);
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
});

test.afterEach(async ({ page }) => {
  expect(uiErrors.get(page), 'browser UI errors').toEqual([]);
});

test('logout clears the session and allows a clean login again', async ({ page }) => {
  test.setTimeout(90_000);
  const data = readE2eData();
  await login(page, data);
  await logout(page);

  // Reuse this running app to exercise a newly created account scope.
  await submitLogin(page, data);
  await page.getByRole('tab', { name: 'Groups', exact: true }).click();
  await expect(page.locator('body')).toContainText(data.groupName, { timeout: 30_000 });
  await logout(page);

  // A full reload must remain signed out, then still allow a fresh login.
  await login(page, data);
  await page.getByRole('tab', { name: 'Groups', exact: true }).click();
  await expect(page.locator('body')).toContainText(data.groupName, { timeout: 30_000 });
});

async function logout(page: Page): Promise<void> {
  await page.getByRole('tab', { name: 'Profile', exact: true }).click();
  await page.getByRole('button', { name: 'Settings', exact: true }).click();
  await page.mouse.move(225, 650);
  await page.mouse.wheel(0, 1600);
  await page.getByRole('button', { name: 'Logout', exact: true }).click();
  await page.getByRole('alertdialog').getByRole('button', { name: 'Logout', exact: true }).click();
  await page.waitForURL(/#\/login/, { timeout: 30_000 });
  await expect(page.locator('input[aria-label="Name"]')).toBeVisible();
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

  await submitLogin(page, data);
}

async function submitLogin(page: Page, data: E2eData): Promise<void> {
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

// Full Chromium supports the simulated camera; headless shell rejects media capture.
test.use({
  channel: 'chromium',
  launchOptions: { args: ['--use-fake-device-for-media-stream'] },
});

test.describe('web camera access', () => {
  test.use({
    permissions: ['camera'],
  });

  test('requests video only when camera opens and starts a preview', async ({ page }) => {
    await page.addInitScript(() => {
      const mediaDevices = navigator.mediaDevices;
      const getUserMedia = mediaDevices.getUserMedia.bind(mediaDevices);
      mediaDevices.getUserMedia = async (constraints) => {
        document.documentElement.dataset.cameraRequested = 'true';
        if (constraints?.audio) {
          throw new Error('Photo capture must not request microphone access');
        }
        try {
          return await getUserMedia(constraints);
        } catch (error) {
          document.documentElement.dataset.cameraError = String(error);
          throw error;
        }
      };
    });
    await login(page, readE2eData());
    await expect(page.locator('html')).not.toHaveAttribute('data-camera-requested', 'true');
    await page.getByRole('tab', { name: 'Camera', exact: true }).click();
    await expect(page.locator('html')).toHaveAttribute('data-camera-requested', 'true');
    await expect(page.locator('html')).not.toHaveAttribute('data-camera-error', /.+/);
    await expect.poll(() => page.locator('video').evaluateAll((videos) =>
      videos.some((video) => video.readyState >= 2 && video.videoWidth > 0),
    ), { timeout: 30_000 }).toBe(true);
    await expect(page.locator('body')).not.toContainText('No cameras are available');
  });
});
