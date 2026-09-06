import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';

const root = resolve(process.argv[2] ?? fileURLToPath(new URL('../../build/image-probe', import.meta.url)));
// Independently encoded 1x1 red PNG.
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC', 'base64');
const mime = { '.js': 'application/javascript', '.mjs': 'application/javascript', '.wasm': 'application/wasm', '.html': 'text/html', '.png': 'image/png', '.json': 'application/json' };
let target;
let apiRequests = 0;
let imageRequests = 0;
let storageOrigin;
const storage = createServer((req, res) => {
  if (req.url !== '/image.png') { res.writeHead(404).end(); return; }
  imageRequests++;
  res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Content-Type': 'image/png' });
  res.end(png);
});
const apiPaths = new Set([
  '/api/v2/pins/local-image/image',
  '/api/v2/users/local-image/profile_picture',
  '/api/v2/users/local-image/profile_picture_small',
  '/api/v2/groups/local-image/profile_image',
  '/api/v2/groups/local-image/profile_image_small',
  '/api/v2/groups/local-image/pin_image',
]);
const app = createServer(async (req, res) => {
  try {
    const pathname = new URL(req.url, 'http://localhost').pathname;
    if (apiPaths.has(pathname)) {
      apiRequests++;
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(`${storageOrigin}/image.png`);
      return;
    }
    if (pathname === '/seed.png') { res.writeHead(200, { 'Content-Type': 'image/png' }).end(png); return; }
    // The diagnostic entry point needs no third-party page scripts or config.
    if (pathname === '/') {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end('<!doctype html><html><head><base href="/"></head><body><script src="flutter_bootstrap.js" async></script></body></html>');
      return;
    }
    const filename = resolve(root, `.${decodeURIComponent(pathname)}`);
    if (!filename.startsWith(root + sep)) { res.writeHead(403).end(); return; }
    let body = await readFile(filename);
    if (pathname === '/flutter_bootstrap.js') {
      const text = body.toString();
      const pattern = /(_flutter\.buildConfig\s*=\s*)(\{.*?\})(;\s*\n\s*_flutter\.loader\.load)/s;
      assert.match(text, pattern, 'Expected Flutter build configuration');
      body = text.replace(pattern, (_, prefix, json, suffix) => {
        const config = JSON.parse(json);
        config.builds = config.builds.filter(build => build.compileTarget === target);
        assert.ok(config.builds.length, `Missing ${target} build`);
        return prefix + JSON.stringify(config) + suffix;
      });
    }
    res.writeHead(200, { 'Content-Type': mime[extname(filename)] ?? 'application/octet-stream' });
    res.end(body);
  } catch (error) {
    if (error.code !== 'ENOENT') console.error(error);
    res.writeHead(404).end();
  }
});
const listen = server => new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  await listen(storage);
  await listen(app);
  storageOrigin = `http://127.0.0.1:${storage.address().port}`;
  const appOrigin = `http://127.0.0.1:${app.address().port}`;
  browser = await chromium.launch({
    executablePath: process.env.CHROME_EXECUTABLE || undefined,
    args: ['--no-sandbox', '--no-proxy-server', '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1'],
  });
  for (target of ['dart2wasm', 'dart2js']) {
    for (const mode of ['fresh', 'migration', 'retained-empty']) {
      apiRequests = imageRequests = 0;
      const context = await browser.newContext({ serviceWorkers: 'block' });
      const blocked = [];
      const errors = [];
      await context.route('**/*', route => {
        const url = new URL(route.request().url());
        if (url.origin === appOrigin || url.origin === storageOrigin) return route.continue();
        blocked.push(url.origin + url.pathname);
        return route.abort();
      });
      try {
        const page = await context.newPage();
        page.on('pageerror', error => errors.push(error.message));
        page.on('console', message => {
          if (process.env.PROBE_VERBOSE || message.text().startsWith('IMAGE PROBE FAILED')) console.error(message.text());
        });
        await page.goto(`${appOrigin}/?mode=${mode}`);
        await page.waitForFunction(() => document.body.hasAttribute('data-image-probe'), null, { timeout: 60000 });
        assert.equal(await page.getAttribute('body', 'data-image-probe'), 'passed', `${target}/${mode}`);
        assert.deepEqual(blocked, [], 'Unexpected external request was blocked');
        assert.deepEqual(errors, [], 'Browser runtime errors');
        const expectedDownloads = mode === 'migration' ? 0 : 6;
        assert.equal(apiRequests, expectedDownloads, 'Image URL requests');
        assert.equal(imageRequests, expectedDownloads, 'Cross-origin PNG downloads');
        if (mode === 'fresh') {
          // Reopen the browser database and verify the images survive reload.
          await page.reload();
          await page.waitForFunction(() => document.body.hasAttribute('data-image-probe'), null, { timeout: 60000 });
          assert.equal(await page.getAttribute('body', 'data-image-probe'), 'passed');
          assert.equal(apiRequests, 6, 'Warm cache must not request URLs again');
          assert.equal(imageRequests, 6, 'Warm cache must not download again');
          assert.deepEqual(blocked, []);
          assert.deepEqual(errors, []);
        }
        console.log(`PASS ${target}/${mode}: all six image types decoded`);
      } finally {
        await context.close();
      }
    }
  }
} finally {
  await browser?.close();
  app.close();
  storage.close();
}
