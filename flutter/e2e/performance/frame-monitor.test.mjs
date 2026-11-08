import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chromium } from '@playwright/test';
import { startFrameMonitor, summarizeFrames } from './frame-monitor.js';

test('reports an isolated stall even when p95 hides it', () => {
  const result = summarizeFrames([...Array(199).fill(16), 180]);
  assert.equal(result.p95Ms, 16);
  assert.equal(result.maxMs, 180);
  assert.equal(result.stallsOver100Ms, 1);
  assert.equal(result.framesOver34Ms, 1);
});

test('rejects an empty recording instead of reporting a pass', () => {
  assert.throws(() => summarizeFrames([]), /No frame samples/);
});

test('browser monitor detects a deliberate main-thread stall', async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await page.goto('about:blank');
    await page.evaluate(startFrameMonitor);
    await page.waitForTimeout(200);
    await page.evaluate(() => {
      const end = performance.now() + 180;
      while (performance.now() < end) { /* deliberate test stall */ }
    });
    await page.waitForTimeout(200);
    const samples = await page.evaluate(() => window.__frameMonitor.stop());
    assert.ok(summarizeFrames(samples).stallsOver100Ms >= 1);
  } finally {
    await browser.close();
  }
});
