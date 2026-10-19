import { expect, test, type Page } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { dataPath } from '../test-data-path.js';

// Opt in: this creates 100 real photo objects in the disposable API fixture.
test.skip(process.env.E2E_PROFILE_IMAGES !== '1', 'Set E2E_PROFILE_IMAGES=1 for the image stress suite');
test.describe.configure({ mode: 'serial' });
let pinId: string;
let api: string;
let token: string;

async function request(path: string, body?: unknown) {
  const response = await fetch(api + path, {
    method: body ? 'POST' : 'GET',
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  expect(response.ok, `${path}: ${response.status}`).toBeTruthy();
  return response.json();
}

test.beforeAll(async () => {
  test.setTimeout(120_000);
  const data = JSON.parse(readFileSync(dataPath(), 'utf8'));
  api = data.apiUrl;
  const user = await request('/api/v2/public/login', { username: data.username, password: data.password });
  token = user.accessToken;
  const pins = await request(`/api/v2/pins?groupId=${data.groupId}&size=100&page=0&withImage=false`);
  let pin = pins.items.find((p: { description?: string }) => p.description === 'Profile image browser fixture');
  const assets = ['art.jpeg', 'photography.jpeg', 'fresh.jpeg', 'country-master.jpeg', 'traveler.jpeg', 'mona.jpg']
    .map((name) => readFileSync(resolve(import.meta.dirname, '../../assets/achievements', name)).toString('base64'));
  pin ??= await request('/api/v2/pins', {
    image: assets[0], latitude: 48.137154, longitude: 11.576124,
    userId: data.userId, groupId: data.groupId, description: 'Profile image browser fixture',
  });
  pinId = pin.id;
  const photos = await request(`/api/v2/pins/${pinId}/photos`);
  for (let index = photos.filter((p: { isOriginal: boolean }) => !p.isOriginal).length; index < 100; index++) {
    await request(`/api/v2/pins/${pinId}/photos`, {
      image: assets[index % assets.length], idempotencyKey: randomUUID(),
      latitude: 48.137154, longitude: 11.576124, accuracyMeters: 5,
      caption: `Browser image ${index}`,
    });
  }
});

async function profile(page: Page) {
  const data = JSON.parse(readFileSync(dataPath(), 'utf8'));
  await page.goto('/');
  const semantics = page.locator('flt-semantics-placeholder');
  await semantics.waitFor({ state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(500);
  await semantics.focus();
  await page.keyboard.press('Enter');
  await page.getByRole('button', { name: 'Sign in with password', exact: true }).click();
  // The native autofill fields keep stable IDs across the auth-mode switch.
  await page.locator('#stick-it-login-password').waitFor();
  for (const [id, value] of [['username', data.username], ['password', data.password]]) {
    const input = page.locator(`#stick-it-login-${id}`);
    await input.click();
    await page.waitForTimeout(150);
    await input.fill(value);
  }
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await page.waitForURL(/#\/home/, { timeout: 30_000 });
  await page.getByRole('tab', { name: 'Profile', exact: true }).click();
  await expect(page.getByText('Sticks', { exact: true })).toBeVisible();
}

const isPhoto = (url: string) => url.includes('/photos/') && url.includes('.jpg');

test('100-photo profile loads a bounded window and survives fast scroll reversals', async ({ page }, info) => {
  test.setTimeout(90_000);
  const errors: string[] = [];
  const photos: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('response', (response) => {
    if (isPhoto(response.url()) && response.status() === 200) photos.push(new URL(response.url()).pathname);
  });
  await page.route('**/*', async (route) => {
    if (isPhoto(route.request().url())) await new Promise((resolve) => setTimeout(resolve, 150));
    await route.continue();
  });
  await profile(page);
  await expect.poll(() => new Set(photos).size, { timeout: 15_000 }).toBeGreaterThanOrEqual(12);
  expect(new Set(photos).size, 'distant photos should remain unloaded').toBeLessThan(45);
  await page.screenshot({ path: info.outputPath('profile-initial.png') });
  await page.mouse.move(220, 650);
  for (let i = 0; i < 8; i++) {
    await page.mouse.wheel(0, 950);
    await page.waitForTimeout(100);
  }
  await expect.poll(() => new Set(photos).size, { timeout: 15_000 }).toBeGreaterThan(45);
  await page.screenshot({ path: info.outputPath('profile-scrolled.png') });
  const downloaded = photos.length;
  for (let i = 0; i < 8; i++) {
    await page.mouse.wheel(0, -950);
    await page.waitForTimeout(100);
  }
  await page.waitForTimeout(1000);
  expect(photos.length - downloaded, 'reversals should reuse loaded objects').toBeLessThan(20);
  expect(errors).toEqual([]);
  await page.screenshot({ path: info.outputPath('profile-returned.png') });
});

test('expired photo URLs renew and load instead of leaving placeholders', async ({ page }, info) => {
  test.setTimeout(90_000);
  let histories = 0;
  let expired = 0;
  const loaded = new Set<string>();
  await page.route(`**/api/v2/pins/${pinId}/photos`, async (route) => {
    histories++;
    const response = await route.fetch();
    if (histories !== 1) return route.fulfill({ response });
    const photos = await response.json();
    for (const photo of photos) {
      if (photo.isOriginal) continue;
      if (photo.image) photo.image += '&browser_expired=1';
      if (photo.imageThumbnail) photo.imageThumbnail += '&browser_expired=1';
    }
    await route.fulfill({ response, json: photos });
  });
  await page.route('**/*browser_expired=1', async (route) => {
    expired++;
    await route.fulfill({ status: 403, body: 'Expired signed URL', headers: { 'Access-Control-Allow-Origin': '*' } });
  });
  page.on('response', (response) => {
    if (isPhoto(response.url()) && response.status() === 200) loaded.add(new URL(response.url()).pathname);
  });
  await profile(page);
  await expect.poll(() => loaded.size, { timeout: 20_000 }).toBeGreaterThanOrEqual(12);
  expect(expired).toBeGreaterThan(0);
  expect(histories).toBeGreaterThan(1);
  expect(histories, 'renewal should be shared by nearby tiles').toBeLessThan(6);
  await page.screenshot({ path: info.outputPath('profile-renewed.png') });
});

test('a still-loading profile photo opens the selected detail photo', async ({ page }, info) => {
  test.setTimeout(90_000);
  await page.route('**/*', async (route) => {
    if (isPhoto(route.request().url())) await new Promise((resolve) => setTimeout(resolve, 2000));
    await route.continue();
  });
  await profile(page);
  // Tap the first tile in the app's three-column profile grid while downloading.
  await page.mouse.click(75, 300);
  await expect(page).toHaveURL(/photo=/, { timeout: 15_000 });
  await page.screenshot({ path: info.outputPath('photo-detail.png') });
});
