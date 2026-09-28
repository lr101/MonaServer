import { createHash } from 'node:crypto';
import { expect, test } from '@playwright/test';
import type { Page, Response } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { dataPath } from '../test-data-path.js';

type E2eData = {
  apiUrl: string;
  username: string;
  password: string;
};

test('editing a group refreshes its cached picture in the overview', async ({ page }) => {
  test.setTimeout(120_000);
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });

  const data = JSON.parse(readFileSync(dataPath(), 'utf8')) as E2eData;
  await login(page, data);
  await page.locator('[role="tab"][aria-label="Groups"]').click();
  await page.getByRole('button', { name: 'Show menu' }).click();
  await page.getByRole('menuitem', { name: 'Create a new group', exact: true }).click();

  const groupName = `Image refresh ${Date.now()}`;
  await chooseAndCropImage(page, resolve(process.cwd(), '../assets/achievements/art.jpeg'));
  await typeFlutterField(page, 'Group name', groupName);
  await typeFlutterField(page, 'Description', 'Disposable UI image refresh check.');

  const createResponsePromise = page.waitForResponse((response) => {
    const request = response.request();
    return new URL(response.url()).pathname === '/api/v2/groups' && request.method() === 'POST';
  });
  await page.getByRole('button', { name: 'Create group', exact: true }).click();
  const createResponse = await createResponsePromise;
  expect(createResponse.ok()).toBe(true);
  const group = (await createResponse.json()) as { id: string };
  const authorization = (await createResponse.request().allHeaders()).authorization;
  expect(authorization).toMatch(/^Bearer /);

  try {
    await expect(page.locator('body')).toContainText(groupName, { timeout: 30_000 });
    const groupRow = page.getByRole('button', { name: new RegExp(escapeRegExp(groupName)) });
    await groupRow.click();

    const initialImageResponsePromise = waitForGroupImage(page, group.id, 'group_profile.png');
    const initialImageResponse = await initialImageResponsePromise;
    const initialImageHash = hash(await initialImageResponse.body());
    await page.waitForTimeout(500);
    const initialAvatarHash = hash(
      await page.screenshot({ clip: { x: 66, y: 60, width: 80, height: 80 } }),
    );

    await page.getByRole('button', { name: 'Show menu' }).click();
    await page.getByRole('menuitem', { name: 'Edit Group (as admin)', exact: true }).click();
    await chooseAndCropImage(
      page,
      resolve(process.cwd(), '../assets/achievements/world-hero.jpeg'),
    );

    const refreshedImagesPromise = Promise.all([
      waitForGroupImage(page, group.id, 'group_profile.png'),
      waitForGroupImage(page, group.id, 'group_profile_small.png'),
      waitForGroupImage(page, group.id, 'group_pin.png'),
    ]);
    const updateResponsePromise = page.waitForResponse((response) => {
      const request = response.request();
      return (
        new URL(response.url()).pathname === `/api/v2/groups/${group.id}` &&
        request.method() === 'PUT'
      );
    });
    await page.getByRole('button', { name: 'Save changes', exact: true }).click();
    const updateResponse = await updateResponsePromise;
    expect(updateResponse.ok()).toBe(true);

    const [largeImageResponse] = await refreshedImagesPromise;
    expect(hash(await largeImageResponse.body())).not.toBe(initialImageHash);
    await expect(page.locator('body')).toContainText(groupName);
    await expect
      .poll(
        async () =>
          hash(await page.screenshot({
            clip: { x: 66, y: 60, width: 80, height: 80 },
          })),
        { timeout: 10_000 },
      )
      .not.toBe(initialAvatarHash);
    expect(errors).toEqual([]);
  } finally {
    const deleteResponse = await page.request.delete(
      `${data.apiUrl}/api/v2/groups/${group.id}`,
      { headers: { Authorization: authorization } },
    );
    expect(deleteResponse.ok()).toBe(true);
  }
});

async function login(page: Page, data: E2eData): Promise<void> {
  await page.goto('/');
  await page.waitForFunction(
    () => document.querySelector('#splash-screen') === null,
    undefined,
    { timeout: 30_000 },
  );
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 15_000 });
  await page.waitForTimeout(500);
  await placeholder.focus();
  await page.keyboard.press('Enter');

  await page.getByRole('button', { name: 'Sign in with password', exact: true }).click();
  await typeFlutterField(page, 'Username', data.username);
  await typeFlutterField(page, 'Password', data.password);
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await page.waitForURL(/#\/home/, { timeout: 30_000 });
}

async function typeFlutterField(page: Page, name: string, value: string): Promise<void> {
  const field = page.getByRole('textbox', { name, exact: true });
  await field.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(value);
}

async function chooseAndCropImage(page: Page, imagePath: string): Promise<void> {
  const chooser = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Change image' }).click();
  await (await chooser).setFiles(imagePath);
  await page.locator('.cropper-container').waitFor({ state: 'visible' });
  await page.waitForTimeout(400);
  await page.mouse.click(await page.evaluate(() => window.innerWidth - 24), 28);
  await page.locator('.cropper-container').waitFor({ state: 'detached' });
}

function waitForGroupImage(page: Page, groupId: string, filename: string): Promise<Response> {
  return page.waitForResponse((response) => {
    const path = new URL(response.url()).pathname;
    return (
      response.request().method() === 'GET' &&
      path.endsWith(`/groups/${groupId}/${filename}`) &&
      response.ok()
    );
  }, { timeout: 30_000 });
}

function hash(bytes: Buffer): string {
  return createHash('sha256').update(bytes).digest('hex');
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
