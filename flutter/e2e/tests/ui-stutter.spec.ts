import { createHash } from 'node:crypto';
import { cpus, hostname } from 'node:os';
import { execFileSync } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import { expect, test } from '@playwright/test';
import { startTrace, finishTrace } from '../performance/trace-capture';
import { dataPath } from '../test-data-path.js';
import { startFrameMonitor, summarizeFrames } from '../performance/frame-monitor.js';

declare global {
  interface Window {
    __frameMonitor: { stop(): number[] };
  }
}

test.skip(process.env.E2E_PERFORMANCE !== '1', 'Opt in with npm run test:performance');

test('repeated navigation and feed scrolling stay within the frame-stall budget', async ({ page, browserName }, info) => {
  test.setTimeout(240_000);
  expect(browserName).toBe('chromium');
  const data = JSON.parse(await readFile(dataPath(), 'utf8'));
  const errors: string[] = [];
  page.on('console', message => { if (/error|exception|failed|state/i.test(message.text())) console.log('Flutter error:', message.text().replace(/https?:\/\/\S+/g, '[url]').slice(0, 1200)); });
  page.on('pageerror', error => { errors.push(error.message); console.log('Application error:', error.message); });
  page.on('requestfailed', request => { if (request.failure()?.errorText !== 'net::ERR_ABORTED') console.log('Request failed:', new URL(request.url()).pathname, request.failure()?.errorText); });
  page.on('response', response => { if (response.status() >= 400) console.log('HTTP error:', response.status(), new URL(response.url()).pathname); });
  await page.goto('/');
  await page.waitForFunction(() => !document.querySelector('#splash-screen'), null, { timeout: 60_000 });
  await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached' });
  await page.locator('flt-semantics-placeholder').focus();
  await page.keyboard.press('Enter');
  await page.getByRole('button', { name: 'Sign in with password', exact: true }).click();
  for (const [id, value] of [['username', data.username], ['password', data.password]]) {
    const field = page.locator(`#stick-it-login-${id}`);
    await field.click();
    await page.waitForTimeout(150);
    await field.fill(value);
  }
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await page.waitForURL(/#\/home/, { timeout: 60_000 });
  await page.getByRole('tab', { name: 'Groups', exact: true }).click();
  await expect(page.getByRole('button', { name: new RegExp(data.groupName) }).first()).toBeVisible({ timeout: 60_000 });
  await page.getByRole('tab', { name: 'Feed', exact: true }).click();
  await page.waitForTimeout(600);
  await page.getByRole('group', { name: /^Filter groups/ }).getByRole('button').last().click({ force: true });
  await page.getByRole('button', { name: 'Select All', exact: true }).click();
  await page.keyboard.press('Escape');
  await page.reload();
  await page.waitForFunction(() => !document.querySelector('#splash-screen'), null, { timeout: 60_000 });
  await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached' });
  await page.locator('flt-semantics-placeholder').focus();
  await page.keyboard.press('Enter');
  await page.getByRole('tab', { name: 'Feed', exact: true }).click();
  await page.waitForTimeout(600);

  await page.mouse.move(220, 450);
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(600);
  await page.mouse.wheel(0, -400);
  // Never benchmark an empty feed or a login/loading screen.
  await expect(page.getByRole('button', { name: /^Show map(?:\s|$)/ }).first()).toBeVisible({ timeout: 60_000 });

  const session = await page.context().newCDPSession(page);
  // Fixed stress level, not a claim to emulate a particular phone.
  await session.send('Emulation.setCPUThrottlingRate', { rate: 4 });
  const destinations = ['Groups', 'Map', 'Profile', 'Feed'];
  const results: { phase: string; gapsMs: number[]; summary: ReturnType<typeof summarizeFrames> }[] = [];
  async function navigate(name: string) {
    const tab = page.getByRole('tab', { name, exact: true });
    await tab.click();
    await expect(tab).toHaveAttribute('aria-selected', 'true');
    const ready = name === 'Groups' ? /^Find groups/ :
      name === 'Map' ? 'My location' : name === 'Profile' ? 'Settings' : /^Show map(?:\s|$)/;
    await expect(page.getByRole('button', { name: ready, exact: typeof ready === 'string' }).first()).toBeVisible();
  }
  // One unmeasured pass pays initial compilation/loading costs. Subsequent
  // eviction/recreation is intentionally part of the measured workload.
  for (const name of destinations) {
    await navigate(name);
    await page.waitForTimeout(600);
  }
  const diagnostic = process.env.E2E_PERF_TRACE === '1';
  const rounds = diagnostic ? 1 : 10;
  if (diagnostic) await startTrace(session);
  try {
    for (let round = 0; round < rounds; round++) {
      for (const name of destinations) {
        await page.evaluate(startFrameMonitor);
        const started = performance.now();
        const windowMs = name === 'Feed' ? 2000 : 1000;
        await navigate(name);
        if (name === 'Feed') {
          await page.waitForTimeout(Math.max(0, started + 500 - performance.now()));
          await page.mouse.move(220, 450);
          for (const delta of [550, 550, -550, -550]) {
            await page.mouse.wheel(0, delta);
            await page.waitForTimeout(200);
          }
        }
        await page.waitForTimeout(Math.max(0, started + windowMs - performance.now()));
        const gapsMs = await page.evaluate(() => window.__frameMonitor.stop());
        results.push({ phase: `${round + 1}:${name}`, gapsMs, summary: summarizeFrames(gapsMs) });
      }
    }
  } finally {
    if (diagnostic) await finishTrace(session, info.outputPath('ui-trace.json'));
    await session.send('Emulation.setCPUThrottlingRate', { rate: 1 });
    const artifactPath = info.outputPath('ui-frame-gaps.json');
    await writeFile(artifactPath, JSON.stringify({
        schemaVersion: 1, workloadId: 'navigation-feed', workloadVersion: 2,
        phaseWindowsMs: { navigation: 1000, feed: 2000 },
        cpuThrottle: 4, rounds, viewport: page.viewportSize(),
        browser: { name: browserName, version: page.context().browser()!.version() },
        hostFingerprint: createHash('sha256').update(JSON.stringify([hostname(), cpus().map(cpu => cpu.model)])).digest('hex'),
        fixtureFingerprint: createHash('sha256').update(JSON.stringify([data.userId, data.groupId, data.apiUrl])).digest('hex'),
        build: {
          gitSha: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
          mode: diagnostic ? 'diagnostic' : 'release',
          bundleSha256: createHash('sha256').update(await readFile('../build/web/main.dart.wasm')).digest('hex'),
        },
        userAgent: await page.evaluate(() => navigator.userAgent),
        results,
      }, null, 2));
    await info.attach('frame-report.json', { path: artifactPath, contentType: 'application/json' });
    await session.detach();
  }
  expect(errors, 'uncaught application errors').toEqual([]);
  for (const { phase, summary } of results) {
    const windowMs = phase.endsWith(':Feed') ? 2000 : 1000;
    expect.soft(Math.abs(summary.durationMs - windowMs), `${phase}: fixed recording window`).toBeLessThanOrEqual(100);
    expect.soft(summary.samples, `${phase}: monitor must observe frames`).toBeGreaterThan(10);
    expect.soft(summary.stallsOver100Ms, `${phase}: ${JSON.stringify(summary)}`).toBe(0);
  }
});
