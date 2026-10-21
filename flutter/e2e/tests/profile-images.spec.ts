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

async function login(page: Page) {
  const data = JSON.parse(readFileSync(dataPath(), 'utf8'));
  await page.goto('/');
  await page.waitForFunction(() => document.querySelector('#splash-screen') === null, undefined, { timeout: 30_000 });
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
}

async function profile(page: Page) {
  await login(page);
  await page.getByRole('tab', { name: 'Profile', exact: true }).click();
  await expect(page.getByText('Sticks', { exact: true })).toBeVisible();
}

const isPhoto = (url: string) => url.includes('/photos/') && url.includes('.jpg');

test('profile shows the grid immediately and loads nearby thumbnails as it scrolls', async ({ page }, info) => {
  test.setTimeout(90_000);
  const errors: string[] = [];
  const photos: string[] = [];
  const entries = await request(`/api/v2/pins/${pinId}/photos`);
  const delayed = entries.find((photo: { caption?: string }) => photo.caption === 'Browser image 99');
  expect(delayed?.imageThumbnail).toBeTruthy();
  const blockedPath = new URL(delayed.imageThumbnail).pathname;
  let release!: () => void;
  let blocked = false;
  const gate = new Promise<void>((resolve) => { release = resolve; });
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('response', (response) => {
    if (isPhoto(response.url()) && response.status() === 200) photos.push(new URL(response.url()).pathname);
  });
  await page.route('**/*', async (route) => {
    const path = new URL(route.request().url()).pathname;
    if (path === blockedPath) {
      blocked = true;
      await gate;
    } else if (isPhoto(route.request().url())) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    await route.continue();
  });
  await profile(page);
  const firstTile = page.getByRole('tabpanel').getByRole('button').first();
  await expect(firstTile).toBeVisible({ timeout: 30_000 });
  await expect.poll(() => blocked).toBe(true);
  await expect(page.getByLabel('Loading photos', { exact: true })).toHaveCount(0);
  await expect.poll(() => new Set(photos).size).toBeGreaterThan(0);
  const initialDownloads = new Set(photos).size;
  expect(initialDownloads).toBeLessThan(100);
  await page.screenshot({ path: info.outputPath('profile-progressive.png') });
  release();
  await page.screenshot({ path: info.outputPath('profile-initial.png') });
  await page.mouse.move(220, 650);
  for (let i = 0; i < 3; i++) {
    await page.mouse.wheel(0, 950);
    await page.waitForTimeout(100);
  }
  await expect.poll(() => new Set(photos).size).toBeGreaterThan(initialDownloads);
  await page.screenshot({ path: info.outputPath('profile-scrolled.png') });
  for (let i = 0; i < 3; i++) {
    await page.mouse.wheel(0, -950);
    await page.waitForTimeout(100);
  }
  await page.waitForTimeout(500);
  expect(new Set(photos).size).toBeGreaterThan(initialDownloads);
  await info.attach('network-summary', { body: JSON.stringify({ initialVisibleThumbnails: initialDownloads, thumbnailsAfterScrolling: new Set(photos).size }), contentType: 'application/json' });
  expect(errors).toEqual([]);
  await page.screenshot({ path: info.outputPath('profile-returned.png') });
});

test('profile galleries discover updates without one history request per pin', async ({ page }, info) => {
  test.setTimeout(90_000);
  const data = JSON.parse(readFileSync(dataPath(), 'utf8'));
  let galleryPages = 0;
  let pinHistoryRequests = 0;
  const loaded = new Set<string>();
  await page.route('**/api/v2/gallery/photos**', async (route) => {
    if (new URL(route.request().url()).searchParams.get('userId') === data.userId) {
      galleryPages++;
    }
    await route.continue();
  });
  await page.route(`**/api/v2/pins/${pinId}/photos`, async (route) => {
    pinHistoryRequests++;
    await route.continue();
  });
  page.on('response', (response) => {
    if (isPhoto(response.url()) && response.status() === 200) loaded.add(new URL(response.url()).pathname);
  });
  await profile(page);
  await expect(page.getByRole('tabpanel').getByRole('button').first()).toBeVisible({ timeout: 30_000 });
  await expect.poll(() => galleryPages).toBeGreaterThan(0);
  await expect.poll(() => loaded.size).toBeGreaterThan(0);
  expect(pinHistoryRequests, 'gallery discovery must not fan out to per-pin history').toBe(0);
  expect(loaded.size, 'gallery metadata must not eagerly download every photo').toBeLessThan(100);
  await page.screenshot({ path: info.outputPath('profile-gallery-no-history-n-plus-one.png') });
});

test('group profile loads a complete gallery snapshot then fetches visible thumbnails progressively', async ({ page }, info) => {
  test.setTimeout(90_000);
  const data = JSON.parse(readFileSync(dataPath(), 'utf8'));
  const entries = await request(`/api/v2/pins/${pinId}/photos`);
  const delayed = entries.find((photo: { caption?: string }) => photo.caption === 'Browser image 99');
  const blockedPath = new URL(delayed.imageThumbnail).pathname;
  const selected = entries.find((photo: { caption?: string }) => photo.caption === 'Browser image 99');
  const next = entries.find((photo: { caption?: string }) => photo.caption === 'Browser image 98');
  const fullPhotos = new Set<string>();
  let releaseHistory!: () => void;
  let releaseImage!: () => void;
  const historyGate = new Promise<void>((resolve) => { releaseHistory = resolve; });
  const imageGate = new Promise<void>((resolve) => { releaseImage = resolve; });
  let galleryPages = 0;
  let imageBlocked = false;
  const photos: string[] = [];
  await page.route('**/*', async (route) => {
    const url = new URL(route.request().url());
    const path = url.pathname;
    // Hold the group page's complete gallery snapshot until its grid is mounted.
    if (path === '/api/v2/gallery/photos' && url.searchParams.get('groupId') === data.groupId) {
      galleryPages++;
      await historyGate;
    }
    if (path === blockedPath) {
      imageBlocked = true;
      await imageGate;
    }
    await route.continue();
  });
  page.on('response', (response) => {
    if (isPhoto(response.url()) && response.status() === 200) {
      const path = new URL(response.url()).pathname;
      photos.push(path);
      if (!path.endsWith('.thumbnail.jpg')) fullPhotos.add(path);
    }
  });
  try {
    // Gate any background group refresh as well as the page's initial read.
    // This fixture uses a fresh browser context and isolated preview database.
    await login(page);
    await page.getByRole('tab', { name: 'Groups', exact: true }).click();
    await page.getByRole('button', { name: new RegExp(data.groupName) }).click();
    await page.getByRole('tab', { name: 'Pins', exact: true }).click();
    await expect.poll(() => galleryPages, { timeout: 20_000 }).toBeGreaterThan(0);
    await page.screenshot({ path: info.outputPath('group-gallery-loading.png') });
    releaseHistory();
    const tile = page.getByRole('tabpanel').getByRole('button').first();
    await expect(tile).toBeVisible({ timeout: 30_000 });
    await expect.poll(() => imageBlocked).toBe(true);
    await expect(page.getByLabel('Loading photos', { exact: true })).toHaveCount(0);
    await expect.poll(() => new Set(photos).size).toBeGreaterThan(0);
    expect(new Set(photos).size).toBeLessThan(100);
    releaseImage();
    await expect.poll(() => photos.includes(blockedPath)).toBe(true);
    const downloads = photos.length;
    await page.mouse.move(220, 650);
    for (const direction of [1, -1]) {
      for (let i = 0; i < 8; i++) {
        await page.mouse.wheel(0, direction * 950);
        await page.waitForTimeout(100);
      }
    }
    expect(photos.length).toBeGreaterThan(downloads);
    await page.screenshot({ path: info.outputPath('group-complete-grid.png') });
    await tile.click();
    await expect(page.getByRole('heading', { name: 'Group images', exact: true })).toBeVisible();
    await expect.poll(() => fullPhotos.has(new URL(selected.image).pathname), { timeout: 20_000 }).toBe(true);
    await page.mouse.wheel(0, 900);
    await expect.poll(() => fullPhotos.has(new URL(next.image).pathname), { timeout: 20_000 }).toBe(true);
    await page.screenshot({ path: info.outputPath('group-list-full-photos.png') });
    await page.mouse.wheel(0, -900);
    await page.getByRole('button', { name: 'Open photo details', exact: true }).first().click();
    await expect(page.getByRole('heading', { name: 'Pin details', exact: true })).toBeVisible();
    await expect(page.getByRole('group', { name: /Photo 101 of 101.*Browser image 99/ })).toBeVisible();
  } finally {
    releaseHistory();
    releaseImage();
  }
});

test('expired photo URLs renew and load instead of leaving placeholders', async ({ page }, info) => {
  test.setTimeout(90_000);
  const data = JSON.parse(readFileSync(dataPath(), 'utf8'));
  let galleryPages = 0;
  let resolveCalls = 0;
  let expired = 0;
  const loaded = new Set<string>();
  await page.route('**/api/v2/gallery/photos**', async (route) => {
    const response = await route.fetch();
    const url = new URL(route.request().url());
    if (url.searchParams.get('userId') !== data.userId) return route.fulfill({ response });
    galleryPages++;
    if (expired > 0) return route.fulfill({ response });
    const gallery = await response.json();
    for (const item of gallery.items) {
      const photo = item.photo;
      if (photo.isOriginal) continue;
      if (photo.image) photo.image += '&browser_expired=1';
      if (photo.imageThumbnail) photo.imageThumbnail += '&browser_expired=1';
    }
    await route.fulfill({ response, json: gallery });
  });
  await page.route('**/api/v2/photos/resolve', async (route) => {
    resolveCalls++;
    await route.continue();
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
  expect(galleryPages).toBeGreaterThan(0);
  expect(resolveCalls, 'nearby URL renewals should share bounded batches').toBeLessThan(6);
  expect(resolveCalls).toBeGreaterThan(0);
  await expect(page.getByRole('tabpanel').getByRole('button').first()).toBeVisible({ timeout: 30_000 });
  await page.screenshot({ path: info.outputPath('profile-renewed.png') });
});

test('a profile photo opens its selected detail while the full image loads', async ({ page }, info) => {
  test.setTimeout(90_000);
  const photos = await request(`/api/v2/pins/${pinId}/photos`);
  const selectedPhoto = photos.find((photo: { caption?: string }) => photo.caption === 'Browser image 99');
  const selected = selectedPhoto?.id;
  expect(selected).toBeTruthy();
  const thumbnailPath = new URL(selectedPhoto.imageThumbnail).pathname;
  let thumbnailReady = false;
  page.on('response', response => { if (new URL(response.url()).pathname === thumbnailPath && response.ok()) thumbnailReady = true; });
  let pending = 0;
  const fullPhotos = new Map<string, number>();
  page.on('response', (response) => {
    const path = new URL(response.url()).pathname;
    if (isPhoto(response.url()) && !path.endsWith('.thumbnail.jpg') && response.status() === 200) {
      fullPhotos.set(path, (fullPhotos.get(path) ?? 0) + 1);
    }
  });
  await page.route('**/*', async (route) => {
    if (isPhoto(route.request().url()) && !new URL(route.request().url()).pathname.endsWith('.thumbnail.jpg')) {
      pending++;
      await new Promise((resolve) => setTimeout(resolve, 2000));
      pending--;
    }
    await route.continue();
  });
  await profile(page);
  await expect.poll(() => thumbnailReady, { timeout: 20_000 }).toBe(true);
  const tile = page.getByRole('tabpanel').getByRole('button').first();
  await tile.waitFor({ state: 'visible' });
  await tile.click();
  await expect(page.getByRole('heading', { name: 'User images', exact: true })).toBeVisible();
  await expect.poll(() => pending).toBeGreaterThan(0);
  await page.getByRole('button', { name: 'Open photo details', exact: true }).first().click();
  await expect(page.getByRole('heading', { name: 'Pin details', exact: true })).toBeVisible();
  await expect(page.getByRole('group', { name: /Photo 101 of 101.*Browser image 99/ })).toBeVisible();
  await expect.poll(() => [...fullPhotos.keys()].some((path) => path.endsWith(`/photos/${selected}.jpg`)), {
    timeout: 20_000,
  }).toBe(true);
  expect([...fullPhotos.values()].every((count) => count === 1), 'carousels share full-photo downloads').toBe(true);
  await page.screenshot({ path: info.outputPath('photo-detail.png') });
});

test('missing thumbnails fall back to full photos without renewing metadata', async ({ page }, info) => {
  test.setTimeout(90_000);
  const photos = await request(`/api/v2/pins/${pinId}/photos`);
  const updateIds = new Set(photos.filter((photo: { isOriginal: boolean }) => !photo.isOriginal).map((photo: { id: string }) => photo.id));
  let missing = 0;
  let resolveCalls = 0;
  const full = new Set<string>();
  await page.route('**/*', async (route) => {
    const url = route.request().url();
    if (isPhoto(url) && new URL(url).pathname.endsWith('.thumbnail.jpg')) {
      missing++;
      return route.fulfill({ status: 404, body: 'Missing thumbnail', headers: { 'Access-Control-Allow-Origin': '*' } });
    }
    await route.continue();
  });
  page.on('response', (response) => {
    // Startup may resolve an original pin before its gallery metadata arrives.
    // Missing update thumbnails already have full URLs and need no renewal.
    if (new URL(response.url()).pathname === '/api/v2/photos/resolve' &&
        response.request().postDataJSON().photoIds.some((id: string) => updateIds.has(id))) resolveCalls++;
    if (isPhoto(response.url()) && !new URL(response.url()).pathname.endsWith('.thumbnail.jpg') && response.status() === 200) {
      full.add(new URL(response.url()).pathname);
    }
  });
  await profile(page);
  await expect.poll(() => full.size, { timeout: 20_000 }).toBeGreaterThanOrEqual(12);
  expect(missing).toBeGreaterThan(0);
  expect(resolveCalls).toBe(0);
  await expect(page.getByRole('tabpanel').getByRole('button').first()).toBeVisible({ timeout: 30_000 });
  await page.screenshot({ path: info.outputPath('profile-full-fallback.png') });
});

test('wide profile renders network images in dark mode', async ({ page }, info) => {
  test.setTimeout(90_000);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.emulateMedia({ colorScheme: 'dark' });
  const loaded = new Set<string>();
  page.on('response', (response) => {
    if (isPhoto(response.url()) && response.status() === 200) loaded.add(new URL(response.url()).pathname);
  });
  await profile(page);
  await expect.poll(() => loaded.size, { timeout: 15_000 }).toBeGreaterThanOrEqual(12);
  await expect(page.getByRole('tabpanel').getByRole('button').first()).toBeVisible({ timeout: 30_000 });
  await page.screenshot({ path: info.outputPath('profile-wide-dark.png') });
});

test('carousel keeps full photos available after traversing a long update history', async ({ page }, info) => {
  test.setTimeout(240_000);
  const errors: string[] = [];
  const loaded = new Map<string, number>();
  const failed: string[] = [];
  const touch = await page.context().newCDPSession(page);
  const viewport = page.viewportSize() ?? { width: 450, height: 900 };
  const swipe = async (towardPrevious: boolean) => {
    const left = viewport.width * 0.15;
    const right = viewport.width * 0.85;
    const startX = towardPrevious ? left : right;
    const endX = towardPrevious ? right : left;
    const y = viewport.height * 0.4;
    await touch.send('Input.dispatchTouchEvent', {
      type: 'touchStart',
      touchPoints: [{ id: 1, x: startX, y }],
    });
    for (let step = 1; step <= 8; step++) {
      await touch.send('Input.dispatchTouchEvent', {
        type: 'touchMove',
        touchPoints: [{ id: 1, x: startX + (endX - startX) * step / 8, y }],
      });
      await page.waitForTimeout(16);
    }
    await touch.send('Input.dispatchTouchEvent', {
      type: 'touchEnd',
      touchPoints: [],
    });
  };
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('requestfailed', req => { if (isPhoto(req.url())) failed.push(new URL(req.url()).pathname + ': ' + req.failure()?.errorText); });
  page.on('response', response => {
    const path = new URL(response.url()).pathname;
    if (isPhoto(response.url()) && !path.endsWith('.thumbnail.jpg') && response.status() === 200) loaded.set(path, (loaded.get(path) ?? 0) + 1);
  });
  const photos = await request(`/api/v2/pins/${pinId}/photos`);
  const selected = photos.find((photo: { caption?: string }) => photo.caption === 'Browser image 99');
  const thumbnailPath = new URL(selected.imageThumbnail).pathname;
  let thumbnailReady = false;
  page.on('response', response => { if (new URL(response.url()).pathname === thumbnailPath && response.ok()) thumbnailReady = true; });
  await profile(page);
  await expect.poll(() => thumbnailReady, { timeout: 20_000 }).toBe(true);
  await page.getByRole('tabpanel').getByRole('button').first().click();
  await expect(page.getByRole('heading', { name: 'User images', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Open photo details', exact: true }).first().click();
  await expect(page.getByRole('heading', { name: 'Pin details', exact: true })).toBeVisible();
  await expect(page.getByRole('group', { name: /Photo 101 of 101.*Browser image 99/ })).toBeVisible({ timeout: 30_000 });
  await page.screenshot({ path: info.outputPath('carousel-initial.png') });
  for (let index = 99; index >= 0; index--) {
    await swipe(true);
    await expect(page.getByRole('group', { name: new RegExp(`Photo ${index + 1} of 101\\b`) })).toBeVisible();
    await page.waitForTimeout(100);
  }
  await page.waitForTimeout(1000);
  await page.screenshot({ path: info.outputPath('carousel-original-after-updates.png') });
  await info.attach('carousel-network', { body: JSON.stringify({ loaded: [...loaded], errors, failed }), contentType: 'application/json' });
  expect(errors).toEqual([]);
  expect(loaded.size).toBeGreaterThan(80);
  await swipe(false);
  await expect(page.getByRole('group', { name: /Photo 2 of 101/ })).toBeVisible();
  await page.screenshot({ path: info.outputPath('carousel-photo-after-return.png') });
  await touch.detach();
});

test('profile update photo pixels survive opening details and returning', async ({ page }, info) => {
  test.setTimeout(90_000);
  const appBack = () => page.getByRole('button', { name: 'Back', exact: true })
    .or(page.getByRole('button').filter({ hasText: 'Back' })).first().click();
  const loaded = new Set<string>();
  page.on('response', response => {
    if (isPhoto(response.url()) && response.ok()) loaded.add(response.url());
  });
  const photos = await request(`/api/v2/pins/${pinId}/photos`);
  const selected = photos.find((photo: { caption?: string }) => photo.caption === 'Browser image 99');
  const thumbnailPath = new URL(selected.imageThumbnail).pathname;
  let thumbnailReady = false;
  page.on('response', response => { if (new URL(response.url()).pathname === thumbnailPath && response.ok()) thumbnailReady = true; });
  await profile(page);
  await expect.poll(() => thumbnailReady, { timeout: 20_000 }).toBe(true);
  const tile = page.getByRole('tabpanel').getByRole('button').first();
  await expect(tile).toBeVisible();
  await expect.poll(() => loaded.size).toBeGreaterThan(0);
  // Let the thumbnail finish its fade before comparing the displayed pixels.
  await page.waitForTimeout(800);
  const before = await tile.screenshot();
  expect(before.length, 'fixture photograph must be visible before navigation').toBeGreaterThan(2000);
  for (let visit = 0; visit < 2; visit++) {
    await tile.click();
    await expect(page.getByRole('heading', { name: 'User images', exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'Open photo details', exact: true }).first().click();
    await expect(page.getByRole('heading', { name: 'Pin details', exact: true })).toBeVisible();
    if (visit === 0) await appBack();
    else await page.goBack();
    await expect(page.getByRole('heading', { name: 'User images', exact: true })).toBeVisible();
    if (visit === 0) await appBack();
    else await page.goBack();
    await expect(tile).toBeVisible();
    await expect.poll(async () => (await tile.screenshot()).equals(before), {
      message: 'returning to the profile must restore the same photograph',
      timeout: 10_000,
    }).toBe(true);
  }
  await page.screenshot({ path: info.outputPath('profile-after-details.png') });
});
