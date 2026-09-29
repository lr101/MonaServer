import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { createServer } from 'node:http';
import { chromium } from '@playwright/test';

import { createStaticServer } from './static_server.mjs';

test('a completed first visit opens the Flutter app with the network offline', async () => {
  const staticRoot = new URL('../build/web/', import.meta.url);
  const server = createStaticServer({ staticRoot });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const tileServer = createServer((_request, response) => {
    response.writeHead(200, { 'access-control-allow-origin': '*', 'content-type': 'image/png' });
    response.end('tile');
  });
  tileServer.listen(0, '127.0.0.1');
  await once(tileServer, 'listening');
  const address = server.address();
  const tileAddress = tileServer.address();
  assert.ok(address && typeof address !== 'string');
  assert.ok(tileAddress && typeof tileAddress !== 'string');
  const profile = await mkdtemp(join(tmpdir(), 'stickit-offline-'));
  let context;
  try {
    const url = `http://127.0.0.1:${address.port}/`;
    context = await chromium.launchPersistentContext(profile);
    let page = context.pages()[0] ?? await context.newPage();
    await page.goto(url);
    await page.waitForFunction(() => document.querySelector('#splash-screen') === null);
    await page.waitForFunction(() => Boolean(navigator.serviceWorker?.controller), null, {
      timeout: 20_000,
    });

    const dynamicUrls = [
      `${url}api/v2/pins`,
      `${url}monaserver/posts/image.jpg`,
      `http://127.0.0.1:${tileAddress.port}/tiles/1/2/3.png`,
    ];
    const firstFetches = await page.evaluate(async (urls) => Promise.all(urls.map(async (target) => {
      const response = await fetch(target);
      return response.ok;
    })), dynamicUrls);
    assert.deepEqual(firstFetches, [true, false, true]);
    const cachedDynamicUrls = await page.evaluate(async (urls) => {
      const names = await caches.keys();
      const matches = await Promise.all(urls.map(async (target) => {
        for (const name of names) {
          if (await (await caches.open(name)).match(target)) return true;
        }
        return false;
      }));
      return matches;
    }, dynamicUrls);
    assert.deepEqual(cachedDynamicUrls, [false, false, false]);

    await context.close();
    context = await chromium.launchPersistentContext(profile);
    await context.setOffline(true);
    page = context.pages()[0] ?? await context.newPage();
    await page.goto(url);
    await page.waitForFunction(() => document.querySelector('#splash-screen') === null, null, { timeout: 20_000 });
    assert.equal(await page.title(), 'Mona App');
    const offlineFetches = await page.evaluate(async (urls) => Promise.all(urls.map(async (target) => {
      try {
        await fetch(target, { cache: 'no-store' });
        return true;
      } catch {
        return false;
      }
    })), dynamicUrls);
    assert.deepEqual(offlineFetches, [false, false, false]);
  } finally {
    await context?.close();
    server.closeAllConnections();
    tileServer.closeAllConnections();
    await Promise.all([
      new Promise((resolve) => server.close(resolve)),
      new Promise((resolve) => tileServer.close(resolve)),
    ]);
    await rm(profile, { recursive: true, force: true });
  }
});
