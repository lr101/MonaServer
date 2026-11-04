import { mkdir, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { expect, test } from '@playwright/test';
import { dataPath } from '../test-data-path.js';

test.skip(process.env.E2E_VISUAL_CAPTURE !== '1', 'Set E2E_VISUAL_CAPTURE=1 for the debug screenshot workflow');

test('signs in and captures the selected destination', async ({ page }, info) => {
  test.setTimeout(120_000);
  const data = JSON.parse(await readFile(dataPath(), 'utf8')) as {
    username: string;
    password: string;
  };
  const errors: string[] = [];
  const redactUrls = (message: string) => message.replace(/https?:\/\/[^\s'"<>]+/g, (raw) => {
    try {
      const url = new URL(raw);
      return `${url.origin}${url.pathname}`;
    } catch {
      return '[URL]';
    }
  });
  page.on('pageerror', (error) => errors.push(redactUrls(error.message)));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(redactUrls(message.text()));
  });
  await page.goto('/');
  await page.waitForFunction(() => document.querySelector('#splash-screen') === null, null, { timeout: 60_000 });
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 30_000 });
  await placeholder.focus();
  await page.keyboard.press('Enter');
  await page.getByRole('button', { name: 'Sign in with password', exact: true }).click();
  for (const [id, value] of [['username', data.username], ['password', data.password]]) {
    const input = page.locator(`#stick-it-login-${id}`);
    await input.click();
    await page.waitForTimeout(150);
    await input.fill(value);
  }
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await page.waitForURL(/#\/home/, { timeout: 60_000 });
  const destination = process.env.E2E_VISUAL_DESTINATION ?? 'Map';
  if (!['Groups', 'Camera', 'Map', 'Feed', 'Profile'].includes(destination)) {
    throw new Error('E2E_VISUAL_DESTINATION must be Groups, Camera, Map, Feed, or Profile');
  }
  await page.getByRole('tab', { name: destination, exact: true })
    .or(page.getByRole('button', { name: new RegExp(`^${destination} Tab `) }))
    .click();
  await page.mouse.move(0, 0);
  await page.waitForTimeout(1000);
  const outputDir = resolve(process.env.E2E_SCREENSHOT_DIR ?? info.outputDir);
  await mkdir(outputDir, { recursive: true, mode: 0o700 });
  const output = resolve(outputDir, `${destination.toLowerCase()}.png`);
  await page.screenshot({ path: output });
  console.log(`Screenshot: ${output}`);
  expect(errors, 'browser errors').toEqual([]);
});
