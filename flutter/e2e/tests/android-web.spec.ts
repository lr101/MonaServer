import { readFile } from 'node:fs/promises';
import { devices, expect, test, type Page } from '@playwright/test';
import { dataPath } from '../test-data-path.js';

test.skip(process.env.E2E_ANDROID_WEB !== '1', 'Browser checks of Android-facing shared UI; opt in with E2E_ANDROID_WEB=1');
test.use({
  ...devices['Pixel 7'],
  actionTimeout: 15_000,
  channel: 'chromium',
  permissions: ['camera', 'geolocation'],
  geolocation: { latitude: 48.137154, longitude: 11.576124, accuracy: 10 },
  launchOptions: { args: ['--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream'] },
});
const errors = new WeakMap<Page, string[]>();
test.beforeEach(async ({ page }) => {
  errors.set(page, []);
  page.on('pageerror', error => errors.get(page)!.push(error.message));
});
test.afterEach(async ({ page }) => {
  expect(errors.get(page), 'uncaught browser errors').toEqual([]);
});

async function login(page: Page) {
  const data = JSON.parse(await readFile(dataPath(), 'utf8'));
  await page.goto('/');
  await page.waitForFunction(() => !document.querySelector('#splash-screen'), null, { timeout: 60_000 });
  const accessibility = page.locator('flt-semantics-placeholder');
  await accessibility.waitFor({ state: 'attached' });
  await accessibility.tap({ force: true });
  await page.getByRole('button', { name: 'Sign in with password', exact: true }).tap();
  for (const [id, value] of [['username', data.username], ['password', data.password]]) {
    const field = page.locator(`#stick-it-login-${id}`);
    await field.tap();
    await page.waitForTimeout(150);
    await field.fill(value);
  }
  await page.getByRole('button', { name: 'Sign in', exact: true }).tap();
  await page.waitForURL(/#\/home/, { timeout: 60_000 });
}

test('touch navigation, rotation, theme and browser back preserve the task', async ({ page }, info) => {
  test.setTimeout(180_000);
  await login(page);
  await page.getByRole('tab', { name: 'Groups', exact: true }).tap();
  await page.getByRole('button', { name: /^Find groups/ }).tap();
  await expect(page.getByRole('searchbox')).toBeVisible();
  await page.goBack();
  await page.getByRole('button', { name: /^Create group/ }).tap();
  await expect(page.getByRole('heading', { name: 'Create a group', exact: true })).toBeVisible();
  await page.goBack();
  for (const name of ['Groups', 'Camera', 'Map', 'Feed', 'Profile']) {
    const tab = page.getByRole('tab', { name, exact: true });
    await tab.tap();
    await expect(tab).toHaveAttribute('aria-selected', 'true');
  }
  await page.getByRole('tab', { name: 'Feed', exact: true }).tap();
  await page.getByRole('button', { name: /^Show map(?:\s|$)/ }).first().tap();
  await expect(page.getByRole('button', { name: /^Show photo(?:\s|$)/ }).first()).toBeVisible();
  await page.getByRole('button', { name: /^Show photo(?:\s|$)/ }).first().tap();
  await expect(page.getByRole('button', { name: /^Show map(?:\s|$)/ }).first()).toBeVisible();
  await page.getByRole('tab', { name: 'Profile', exact: true }).tap();
  await page.getByRole('button', { name: 'Settings', exact: true }).tap();
  await expect(page.getByRole('switch', { name: /Dark appearance/ })).toBeVisible();
  await page.getByRole('switch', { name: /Dark appearance/ }).tap();
  await page.getByRole('button', { name: 'Edit profile', exact: true }).tap();
  const fields = page.getByRole('textbox');
  await expect(fields.first()).toBeVisible();
  const before = await fields.first().inputValue();
  await page.setViewportSize({ width: 851, height: 393 });
  await expect(fields.first()).toHaveValue(before);
  await page.screenshot({ path: info.outputPath('android-browser-form-landscape.png') });
  await page.setViewportSize({ width: 393, height: 851 });
  await page.goBack();
  await expect(page.getByRole('heading', { name: 'Settings', exact: true })).toBeVisible();
  await page.goBack();
  await expect(page.getByRole('tab', { name: 'Profile', exact: true })).toHaveAttribute('aria-selected', 'true');
  await page.setViewportSize({ width: 851, height: 393 });
  await expect(page.getByRole('button', { name: /^Profile Tab / })).toBeVisible();
  await page.screenshot({ path: info.outputPath('android-browser-rail-landscape.png') });
});

test('touch capture, draft rotation and save reach the local API', async ({ page }, info) => {
  test.setTimeout(180_000);
  await login(page);
  // Camera may default to a different joined group than the active feed filter.
  await page.getByRole('group', { name: /^Filter groups/ }).getByRole('button').last().tap();
  await page.getByRole('button', { name: 'Select All', exact: true }).tap();
  await page.keyboard.press('Escape');
  await page.getByRole('tab', { name: 'Camera', exact: true }).tap();
  await expect(page.locator('video')).toBeVisible({ timeout: 30_000 });
  await page.getByRole('button', { name: 'Take photo', exact: true }).tap();
  const location = page.getByRole('heading', { name: 'Select Location', exact: true });
  const approve = page.getByRole('heading', { name: 'Approve', exact: true });
  await expect(location.or(approve)).toBeVisible({ timeout: 30_000 });
  if (await location.isVisible()) {
    await page.getByRole('button', { name: 'Next', exact: true }).tap();
  }
  await expect(page.getByRole('heading', { name: 'Approve', exact: true })).toBeVisible();
  const title = page.getByRole('textbox', { name: /^Title(?:\s|$)/ });
  const draft = `Android browser check ${Date.now()}`;
  await title.tap();
  await page.waitForTimeout(150);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.insertText(draft);
  await expect(title).toHaveValue(draft);
  await page.getByRole('heading', { name: 'Approve', exact: true }).tap();
  await page.setViewportSize({ width: 851, height: 393 });
  await expect(title).toHaveValue(draft);
  await page.setViewportSize({ width: 393, height: 851 });
  await page.screenshot({ path: info.outputPath('android-browser-approve.png') });
  await title.tap();
  await page.waitForTimeout(150);
  const uploaded = page.waitForResponse(response => new URL(response.url()).pathname === '/api/v2/pins' && response.request().method() === 'POST' && response.ok(), { timeout: 60_000 });
  await page.getByRole('button', { name: 'Upload', exact: true }).tap();
  const response = await uploaded;
  const pin = await response.json();
  const authorization = (await response.request().allHeaders()).authorization;
  try {
    expect(response.request().postDataJSON().title).toBe(draft);
    await expect(page.getByRole('tab', { name: 'Feed', exact: true })).toBeVisible();
    await page.getByRole('tab', { name: 'Feed', exact: true }).tap();
    // Live updates preserve mounted cards and append new photos after them.
    // Look below the retained scroll anchor instead of assuming a prepend.
    const saved = page.getByRole('group', { name: new RegExp(draft) }).first();
    for (let scroll = 0; scroll < 12 && !await saved.isVisible(); scroll++) {
      await page.mouse.move(180, 400);
      await page.mouse.wheel(0, 600);
      await page.waitForTimeout(250);
    }
    await expect(saved).toBeVisible({ timeout: 30_000 });
    await page.screenshot({ path: info.outputPath('android-browser-saved.png') });
  } finally {
    const deleted = await page.request.delete(`${new URL(response.url()).origin}/api/v2/pins/${pin.id}`, { headers: { Authorization: authorization } });
    expect(deleted.ok()).toBe(true);
  }
});


test('compact group header retains actions and achievement catalog', async ({ page }, info) => {
  test.setTimeout(180_000);
  const data = JSON.parse(await readFile(dataPath(), 'utf8'));
  await login(page);
  await page.getByRole('tab', { name: 'Groups', exact: true }).tap();
  await page.getByRole('button', { name: new RegExp(data.groupName) }).first().tap();
  await expect(page.getByRole('button', { name: 'Share group', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Group settings', exact: true }).tap();
  await expect(page.getByRole('button', { name: 'Share group', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Report group', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Leave group', exact: true }).tap();
  await expect(page.getByRole('button', { name: 'Cancel', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Cancel', exact: true }).tap();
  await page.getByRole('button', { name: /^Back/ }).tap();
  await page.getByRole('tab', { name: 'Achievements', exact: true }).tap();
  await page.getByRole('button', { name: /Browse all achievement tiers/ }).tap();
  await page.getByRole('menuitem', { name: 'Pins', exact: true }).tap();
  await expect(page.getByRole('button', { name: 'All achievement tracks', exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('group-all-tiers.png') });
  await page.getByRole('button', { name: /Pins, Gatherer,/ }).tap();
  await expect(page.getByText('Gatherer', { exact: true }).last()).toBeVisible();
  await page.keyboard.press('Escape');
  await page.getByRole('button', { name: 'All achievement tracks', exact: true }).tap();
  await page.setViewportSize({ width: 320, height: 700 });
  await expect(page.getByRole('button', { name: 'Share group', exact: true })).toHaveCount(0);
  await page.screenshot({ path: info.outputPath('group-compact-320.png') });
});

// Provision only a disposable local group; the fixture's own rewards stay untouched.
test('group settings retain admin editing, reporting and reward collection', async ({ page }, info) => {
  test.setTimeout(180_000);
  const data = JSON.parse(await readFile(dataPath(), 'utf8'));
  const api = process.env.E2E_API_URL ?? 'http://127.0.0.1:8081';
  expect(['127.0.0.1', 'localhost', '[::1]']).toContain(new URL(api).hostname);
  await login(page);
  const loginResponse = await page.request.post(`${api}/api/v2/public/login`, { data: { username: data.username, password: data.password } });
  expect(loginResponse.ok()).toBeTruthy();
  const token = await loginResponse.json();
  const headers = { Authorization: `Bearer ${token.accessToken}` };
  const created = await page.request.post(`${api}/api/v2/groups`, { headers, data: {
    name: `Northern Quarter Street Art Collective ${Date.now()}`,
    description: 'Members document murals, stickers and hidden corners. A long description verifies that group information and settings remain reachable.',
    visibility: 0, groupAdmin: token.userId,
    profileImage: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  }});
  expect(created.ok()).toBeTruthy();
  const group = await created.json();
  const pinIds: string[] = [];
  try {
    // Spark requires two active pins; use isolated coordinates for both.
    for (let index = 0; index < 2; index++) {
    const pin = await page.request.post(`${api}/api/v2/pins`, { headers, data: {
      image: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      latitude: 46 + Math.random(), longitude: 8 + Math.random(), userId: token.userId, groupId: group.id,
      description: 'Disposable achievement collection check',
    }});
    expect(pin.ok()).toBeTruthy();
    pinIds.push((await pin.json()).id);
    }
    await page.goto(`/#/groups/${group.id}`);
    await page.waitForFunction(() => !document.querySelector('#splash-screen'), null, { timeout: 60_000 });
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.tap({ force: true });
    await page.getByRole('button', { name: 'Group settings', exact: true }).tap();
    await expect(page.getByRole('button', { name: 'Edit group', exact: true })).toHaveCount(0);
    const nameField = page.getByRole('textbox', { name: /^Group name(?:\s|$)/ });
    const updatedName = `${group.name} updated`;
    await nameField.tap();
    await page.waitForTimeout(150);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.insertText(updatedName);
    await expect(nameField).toHaveValue(updatedName);
    await page.getByRole('heading', { name: 'Group settings', exact: true }).tap();
    const saveButton = page.getByRole('button', { name: 'Save changes', exact: true });
    await saveButton.scrollIntoViewIfNeeded();
    const saved = page.waitForResponse(response => new URL(response.url()).pathname === `/api/v2/groups/${group.id}` && response.request().method() === 'PUT' && response.ok());
    await saveButton.tap();
    const savedResponse = await saved;
    expect((await savedResponse.json()).name).toBe(updatedName);
    await expect(page.getByRole('heading', { name: 'Group settings', exact: true })).toBeVisible();
    await expect(nameField).toHaveValue(updatedName);
    await page.screenshot({ path: info.outputPath('inline-group-edit-saved.png') });
    await page.getByRole('button', { name: 'Report group', exact: true }).scrollIntoViewIfNeeded();
    await page.getByRole('button', { name: 'Report group', exact: true }).tap();
    await expect(page.getByRole('heading', { name: 'Report Issue', exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Report Group', exact: true })).toBeVisible();
    await page.goBack();
    await page.getByRole('button', { name: /^Back/ }).tap();
    await page.getByRole('tab', { name: 'Achievements', exact: true }).tap();
    const ready = page.getByRole('button', { name: /ready to collect/ }).first();
    await ready.tap();
    await expect(page.getByRole('button', { name: 'Collect reward', exact: true })).toBeVisible();
    const claim = page.waitForResponse(response => /\/achievements\/\d+$/.test(new URL(response.url()).pathname) && response.request().method() === 'POST' && response.ok());
    await page.getByRole('button', { name: 'Collect reward', exact: true }).tap();
    await claim;
    await page.getByRole('button', { name: /Browse all achievement tiers/ }).tap();
    await page.getByRole('menuitem', { name: 'Pins', exact: true }).tap();
    await expect(page.getByRole('button', { name: /Pins, Spark,.*collected/ })).toBeVisible();
    await page.screenshot({ path: info.outputPath('group-after-collection.png') });
  } finally {
    for (const pinId of pinIds) expect((await page.request.delete(`${api}/api/v2/pins/${pinId}`, { headers })).ok()).toBeTruthy();
    expect((await page.request.delete(`${api}/api/v2/groups/${group.id}`, { headers })).ok()).toBeTruthy();
  }
});


test('one centered floating dock expands selection on every destination and clears rankings', async ({ page }, info) => {
  test.setTimeout(180_000);
  await login(page);
  const dock = page.getByRole('tablist', { name: 'Main navigation', exact: true });
  await expect(dock).toBeVisible();
  const original = (await dock.boundingBox())!;
  expect(original.x).toBeGreaterThan(0);
  expect(original.x + original.width / 2).toBeCloseTo(page.viewportSize()!.width / 2, 0);
  expect(original.y + original.height).toBeLessThan(page.viewportSize()!.height);
  for (const name of ['Groups', 'Feed', 'Profile', 'Map']) {
    const tab = dock.getByRole('tab', { name, exact: true });
    await tab.tap();
    await expect(tab).toHaveAttribute('aria-selected', 'true');
    await page.waitForTimeout(360);
    const bounds = (await dock.boundingBox())!;
    expect(bounds.x).toBeCloseTo(original.x, 0);
    expect(bounds.y).toBeCloseTo(original.y, 0);
    expect(bounds.width).toBeCloseTo(original.width, 0);
    const selected = (await tab.boundingBox())!;
    const other = (await dock.getByRole('tab', { name: name === 'Map' ? 'Groups' : 'Map', exact: true }).boundingBox())!;
    expect(selected.width).toBeGreaterThan(other.width + 10);
    await page.screenshot({ path: info.outputPath(`floating-dock-${name.toLowerCase()}.png`) });
  }
  const rankings = page.getByRole('button', { name: /^Expand rankings/ });
  const headerBounds = (await rankings.boundingBox())!;
  expect(headerBounds.x).toBeCloseTo(original.x, 0);
  expect(headerBounds.width).toBeCloseTo(original.width, 0);
  expect(headerBounds.y + headerBounds.height).toBeLessThan(original.y);
  await rankings.tap();
  const collapseRankings = page.getByRole('button', { name: /^Collapse rankings/ });
  await expect(collapseRankings).toBeVisible();
  await page.waitForTimeout(360);
  const expandedHeader = (await collapseRankings.boundingBox())!;
  const location = (await page.getByRole('button', { name: 'My location', exact: true }).boundingBox())!;
  expect(location.y + location.height).toBeLessThanOrEqual(expandedHeader.y - 8);
  await page.screenshot({ path: info.outputPath('floating-dock-rankings-expanded.png') });
  expect((await dock.boundingBox())!.y).toBeCloseTo(original.y, 0);
  await page.getByRole('button', { name: /^Collapse rankings/ }).tap();
});


test('a newly captured photo uploads immediately without entering a title', async ({ page }, info) => {
  test.setTimeout(150_000);
  await login(page);
  await page.getByRole('tab', { name: 'Camera', exact: true }).tap();
  await expect(page.locator('video')).toBeVisible({ timeout: 30_000 });
  await page.getByRole('button', { name: 'Take photo', exact: true }).tap();
  const location = page.getByRole('heading', { name: 'Select Location', exact: true });
  const approval = page.getByRole('heading', { name: 'Approve', exact: true });
  await expect(location.or(approval)).toBeVisible({ timeout: 30_000 });
  if (await location.isVisible()) await page.getByRole('button', { name: 'Next', exact: true }).tap();
  await expect(approval).toBeVisible();
  const upload = page.getByRole('button', { name: 'Upload', exact: true });
  const bounds = (await upload.boundingBox())!;
  expect(bounds.x).toBeGreaterThan(0);
  expect(bounds.x + bounds.width / 2).toBeCloseTo(page.viewportSize()!.width / 2, 0);
  expect(bounds.height).toBeGreaterThanOrEqual(48);
  expect(bounds.y + bounds.height).toBeLessThan(page.viewportSize()!.height);
  await page.screenshot({ path: info.outputPath('capture-approval-light.png') });
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.setViewportSize({ width: 320, height: 740 });
  await page.waitForTimeout(360);
  await page.screenshot({ path: info.outputPath('capture-approval-dark.png') });
  const uploaded = page.waitForResponse(response => new URL(response.url()).pathname === '/api/v2/pins' && response.request().method() === 'POST' && response.ok(), { timeout: 60_000 });
  await upload.tap();
  const response = await uploaded;
  const pin = await response.json();
  const authorization = (await response.request().allHeaders()).authorization;
  try {
    await expect(page.getByRole('tab', { name: 'Camera', exact: true })).toBeVisible();
    expect(response.request().postDataJSON().title ?? '').toBe('');
    const saved = await page.request.get(`${new URL(response.url()).origin}/api/v2/pins/${pin.id}`, { headers: { Authorization: authorization } });
    expect(saved.ok()).toBe(true);
    await page.screenshot({ path: info.outputPath('capture-uploaded.png') });
  } finally {
    const deleted = await page.request.delete(`${new URL(response.url()).origin}/api/v2/pins/${pin.id}`, { headers: { Authorization: authorization } });
    expect(deleted.ok()).toBe(true);
  }
});
