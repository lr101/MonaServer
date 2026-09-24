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

test('email-link sign-in remains the default and can switch to password', async ({ page }) => {
  let emailLinkRequests = 0;
  await page.route('**/api/v3/public/auth/email-link/request', async (route) => {
    emailLinkRequests++;
    await route.fulfill({
      status: 202,
      contentType: 'application/json',
      body: '{"accepted":true}',
    });
  });

  await page.goto('/');
  await enableAccessibility(page);
  await expect(page.locator('body')).not.toContainText(/Buff\s+Lisa/i);
  await expect(page.locator('body')).not.toContainText('to continue to');
  await expect(page.getByText('Need an account?', { exact: true })).toBeVisible();
  const identifier = page.locator('input[aria-label="Email or username"]');
  await expect(identifier).toBeVisible();
  await expect(page.getByRole('button', { name: 'Continue', exact: true })).toBeVisible();
  await enterFlutterText(page, 'Email or username', 'person@example.com');
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await expect(
    page.getByText(
      'If an account is eligible, a sign-in link is on its way. Check your inbox.',
    ),
  ).toBeVisible();
  expect(emailLinkRequests).toBe(1);

  await page.getByRole('button', { name: 'Sign in with password', exact: true }).click();
  await expect(page.locator('input[aria-label="Username"]')).toBeVisible();
  await expect(page.locator('input[aria-label="Password"]')).toBeVisible();
  await page.getByRole('button', { name: 'Use email link instead', exact: true }).click();
  await expect(identifier).toBeVisible();
  await expect(page.getByRole('button', { name: 'Continue', exact: true })).toBeVisible();
});

test('password sign-in publishes browser autofill metadata', async ({ page }) => {
  await page.goto('/');
  await page.waitForFunction(
    () => document.querySelector('#splash-screen') === null,
    undefined,
    { timeout: 30_000 },
  );

  // Use the normal Flutter text input bridge. Enabling accessibility switches
  // to proxy inputs whose autocomplete attributes are intentionally disabled.
  await page.mouse.click(130, 532);
  await page.waitForTimeout(400);
  await page.mouse.click(200, 365);

  const username = page.locator('flt-text-editing-host input[name="username"]');
  const password = page.locator(
    'flt-text-editing-host input[name="current-password"]',
  );
  await expect(username).toHaveAttribute('autocomplete', 'username');
  await expect(password).toHaveAttribute('autocomplete', 'current-password');
});

test('secondary auth actions retain 48-pixel hit areas', async ({ page }) => {
  await page.goto('/');
  await enableAccessibility(page);

  for (const name of ['Sign in with password', 'Create account']) {
    const bounds = await page.getByRole('button', { name, exact: true }).boundingBox();
    expect(bounds?.height, `${name} hit area`).toBeGreaterThanOrEqual(48);
  }
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
  await expect(page.locator('input[aria-label="Email or username"]')).toBeVisible();
}

test('rejected refresh returns to login, survives reload, and permits reauthentication', async ({ page }) => {
  test.setTimeout(90_000);
  const data = readE2eData();
  await login(page, data);
  let rejections = 0;
  await page.route('**/api/v2/public/refresh', async (route) => {
    rejections++;
    await route.fulfill({ status: 403, contentType: 'application/json', body: '{}' });
  });
  // The only expected browser error is the refresh response injected above.
  page.on('console', (message) => {
    if (message.type() === 'error' &&
        message.location().url.endsWith('/api/v2/public/refresh') &&
        message.text() === 'Failed to load resource: the server responded with a status of 403 (Forbidden)') {
      const errors = uiErrors.get(page)!;
      const index = errors.lastIndexOf(message.text());
      if (index >= 0) errors.splice(index, 1);
    }
  });
  await page.reload();
  await page.waitForURL(/#\/login/, { timeout: 30_000 });
  await enableAccessibility(page);
  await expect(page.getByText('Your session expired. Sign in again to continue.')).toBeVisible();
  expect(rejections).toBe(1);

  await page.reload();
  await enableAccessibility(page);
  await expect(page.getByText('Your session expired. Sign in again to continue.')).toBeVisible();
  expect(rejections).toBe(1);
  await page.unroute('**/api/v2/public/refresh');
  await submitLogin(page, data);
  await page.getByRole('tab', { name: 'Groups', exact: true }).click();
  await expect(page.locator('body')).toContainText(data.groupName, { timeout: 30_000 });
});

test('login and restored sessions each sync once without navigation retriggers', async ({ page }) => {
  const data = readE2eData();
  let syncRequests = 0;
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === '/api/v3/sync') syncRequests++;
  });
  const firstSync = page.waitForResponse((response) =>
    new URL(response.url()).pathname === '/api/v3/sync' && response.ok());
  await login(page, data);
  await firstSync;
  await page.getByRole('tab', { name: 'Groups', exact: true }).click();
  await expect(page.locator('body')).toContainText(data.groupName, { timeout: 30_000 });
  await page.getByRole('tab', { name: 'Profile', exact: true }).click();
  await page.getByRole('tab', { name: 'Groups', exact: true }).click();
  expect(syncRequests).toBe(1);

  const restoredSync = page.waitForResponse((response) =>
    new URL(response.url()).pathname === '/api/v3/sync' && response.ok());
  await page.reload();
  await enableAccessibility(page);
  await restoredSync;
  await page.getByRole('tab', { name: 'Groups', exact: true }).click();
  await expect(page.locator('body')).toContainText(data.groupName, { timeout: 30_000 });
  expect(syncRequests).toBe(2);
});

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
  // Click waits for the Flutter route transition to settle before editing.
  await page.locator('input').first().click();
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

  // Metadata and batch reads can supply URLs without per-pin image API calls.
  // Verify the browser actually downloads every visible pin image.
  const loadedObjectImages = new Set<string>();
  page.on('response', (response) => {
    const url = new URL(response.url());
    const objectMatch = url.pathname.match(/^\/monaserver\/pins\/([^/]+)\.png$/);
    if (objectMatch && response.ok()) {
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
  await enableAccessibility(page);
  await submitLogin(page, data);
}

async function enableAccessibility(page: Page): Promise<void> {
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
}

async function submitLogin(page: Page, data: E2eData): Promise<void> {
  await page.getByRole('button', { name: 'Sign in with password', exact: true }).click();
  await enterFlutterText(page, 'Username', data.username);
  await enterFlutterText(page, 'Password', data.password);
  await page
    .getByRole('button', { name: 'Sign in', exact: true })
    .click();

  await page.waitForURL(/#\/home/, { timeout: 30_000 });
}

async function enterFlutterText(page: Page, label: string, value: string): Promise<void> {
  const input = page.locator(`input[aria-label="${label}"]`);
  await input.click();
  await expect(input).toBeFocused();
  // Flutter attaches its editing client after DOM focus. Typing in that same
  // frame can lose the first character, especially after a logout transition.
  await page.waitForTimeout(150);
  await input.fill('');
  await input.pressSequentially(value, { delay: 30 });
  await expect(input).toHaveValue(value);
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}


test.use({
  channel: 'chromium',
  launchOptions: { args: ['--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream'] },
});

test.describe('web camera access', () => {
  test.use({
    permissions: ['camera'],
  });

  test('opens a full-frame preview without probing every camera', async ({ page }) => {
    test.setTimeout(60_000);
    await page.addInitScript(() => {
      const devices = navigator.mediaDevices;
      const original = devices.getUserMedia.bind(devices);
      let requests = 0;
      Object.defineProperty(window, '__cameraRequests', { get: () => requests });
      devices.getUserMedia = async (constraints) => {
        requests++;
        return original(constraints);
      };
    });
    await login(page, readE2eData());
    expect(await page.evaluate(() => (window as Window & { __cameraRequests: number }).__cameraRequests)).toBe(0);
    await page.getByRole('tab', { name: 'Camera', exact: true }).click();
    const video = page.locator('video');
    await expect(video).toBeVisible({ timeout: 30_000 });
    await expect(video).toHaveCSS('object-fit', 'contain');
    await expect.poll(() => video.evaluate((element: HTMLVideoElement) => element.readyState)).toBe(4);
    expect(await page.evaluate(() => (window as Window & { __cameraRequests: number }).__cameraRequests)).toBe(2);
    await expect(page.getByRole('button', { name: 'Select camera' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Take photo', exact: true })).toBeVisible();
    await page.screenshot({ path: 'test-results/camera-portrait.png' });
    await page.setViewportSize({ width: 900, height: 450 });
    await expect(video).toBeVisible();
    await page.screenshot({ path: 'test-results/camera-landscape.png' });
    // Mobile browsers may renegotiate stream dimensions after rotation.
    await video.evaluate(async (element: HTMLVideoElement) => {
      const track = (element.srcObject as MediaStream).getVideoTracks()[0];
      await track.applyConstraints({ width: { exact: 640 }, height: { exact: 480 } });
    });
    await expect.poll(() => video.evaluate((element: HTMLVideoElement) =>
      [element.videoWidth, element.videoHeight])).toEqual([640, 480]);
    await expect.poll(() => video.evaluate((element: HTMLVideoElement) => {
      const bounds = element.getBoundingClientRect();
      return bounds.width / bounds.height;
    })).toBeCloseTo(4 / 3, 2);
    await page.getByRole('button', { name: 'Take photo', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Select Location' })).toBeVisible({ timeout: 30_000 });
    await page.goBack();
    await expect(video).toBeVisible();
    await expect(page.getByText('Hold steady capturing ...', { exact: true })).toHaveCount(0);
    await expect.poll(() => video.evaluate((element: HTMLVideoElement) => element.paused)).toBe(false);
    await page.getByRole('button', { name: 'Take photo', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Select Location' })).toBeVisible({ timeout: 30_000 });
    await page.getByRole('button', { name: 'Next', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Approve' })).toBeVisible();
    await page.getByRole('button', { name: 'Back', exact: true }).click();
    await page.getByRole('button', { name: 'Back', exact: true }).click();
    await expect(video).toBeVisible();
    await expect.poll(() => video.evaluate((element: HTMLVideoElement) => element.paused)).toBe(false);
    await expect(page.getByText('Hold steady capturing ...', { exact: true })).toHaveCount(0);
    await page.getByRole('button', { name: 'Take photo', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Select Location' })).toBeVisible({ timeout: 30_000 });
  });
  test('camera permission denial is actionable and retry restores preview', async ({ page }) => {
    await page.addInitScript(() => {
      const devices = navigator.mediaDevices;
      const original = devices.getUserMedia.bind(devices);
      let deny = true;
      devices.getUserMedia = async (constraints) => {
        if (deny) {
          deny = false;
          throw new DOMException('Permission denied', 'NotAllowedError');
        }
        return original(constraints);
      };
    });
    await login(page, readE2eData());
    await page.getByRole('tab', { name: 'Camera', exact: true }).click();
    await expect(page.getByRole('group', { name: /Allow camera access/ })).toBeVisible();
    await page.getByRole('button', { name: 'Retry', exact: true }).click();
    await expect(page.locator('video')).toBeVisible({ timeout: 30_000 });
  });

});
