import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { chromium } from '@playwright/test';

const stateDir = process.argv[2];
if (!stateDir) throw new Error('Usage: node debug_reconnect.mjs <debug session state directory>');
const port = Number((await readFile(resolve(stateDir, 'chrome-port'), 'utf8')).trim());
const appPort = Number((await readFile(resolve(stateDir, 'app-port'), 'utf8')).trim());
for (const value of [port, appPort]) {
  if (!Number.isInteger(value) || value < 1 || value > 65535) throw new Error('Invalid debug session port');
}
const browser = await chromium.connectOverCDP(`http://127.0.0.1:${port}`);
try {
  const page = browser.contexts().flatMap((context) => context.pages()).find((candidate) => {
    const url = new URL(candidate.url());
    return ['127.0.0.1', 'localhost'].includes(url.hostname) && Number(url.port) === appPort;
  });
  if (!page) throw new Error('Flutter-owned Chrome tab was not found');
  await page.reload();
  await page.waitForFunction(() => document.querySelector('#splash-screen') === null, null, { timeout: 60_000 });
  console.log('Reloaded the Flutter-owned Chrome tab; wait for it to reconnect, then use r in the Flutter terminal.');
} finally {
  await browser.close();
}
