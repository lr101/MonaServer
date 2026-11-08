import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import http from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, test } from 'node:test';
import { chromium } from '@playwright/test';
import { createStaticServer } from '../static_server.mjs';

const root = fileURLToPath(new URL('../../../', import.meta.url));
const temporaryDirectories = [];
async function temporaryDirectory(prefix) {
  const directory = await mkdtemp(join(tmpdir(), prefix));
  temporaryDirectories.push(directory);
  return directory;
}
after(async () => {
  await Promise.all(temporaryDirectories.map(directory => rm(directory, { recursive: true, force: true })));
});
const headers = {
  'cross-origin-opener-policy': 'same-origin',
  'cross-origin-embedder-policy': 'credentialless',
};

async function fixture() {
  const directory = await temporaryDirectory('monaserver-isolation-');
  await Promise.all([
    writeFile(join(directory, 'index.html'), '<!doctype html><title>probe</title>'),
    writeFile(join(directory, 'offline-sw.js'), '// service worker'),
    writeFile(join(directory, 'worker.js'), 'postMessage(crossOriginIsolated)'),
    writeFile(join(directory, 'module.mjs'), 'export const ready = true'),
    writeFile(join(directory, 'module.wasm'), Buffer.from([0, 97, 115, 109])),
    writeFile(join(directory, 'asset.js'), 'void 0'),
  ]);
  await chmod(directory, 0o755);
  return directory;
}

async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once('error', reject).listen(0, '127.0.0.1', resolve);
  });
  return server.address().port;
}

async function close(server) {
  await new Promise(resolve => server.close(resolve));
}

async function assertHeaders(base) {
  for (const path of ['/', '/index.html', '/route/inside/app', '/offline-sw.js', '/worker.js', '/module.mjs', '/module.wasm', '/asset.js']) {
    const response = await fetch(`${base}${path}`);
    assert.equal(response.status, 200, path);
    for (const [name, value] of Object.entries(headers)) {
      assert.equal(response.headers.get(name), value, `${path}: ${name}`);
    }
  }
}

async function assertIsolation(base) {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await page.goto(`${base}/`);
    const result = await page.evaluate(() => new Promise(resolve => {
      const worker = new Worker('/worker.js');
      worker.onmessage = event => resolve({ document: crossOriginIsolated, worker: event.data });
    }));
    assert.deepEqual(result, { document: true, worker: true });
  } finally {
    await browser.close();
  }
}

async function startNginx(config, port) {
  const runtime = await temporaryDirectory('monaserver-nginx-');
  await mkdir(join(runtime, 'tmp'), { recursive: true });
  await chmod(runtime, 0o755);
  await chmod(join(runtime, 'tmp'), 0o755);
  const configPath = join(runtime, 'nginx.conf');
  await writeFile(configPath, config);
  const child = spawn('nginx', ['-p', runtime, '-c', configPath, '-g', 'daemon off;'], { stdio: 'ignore' });
  const stopped = new Promise((_, reject) => child.once('exit', code => reject(new Error(`nginx exited ${code}`))));
  for (let attempt = 0; attempt < 50; attempt++) {
    await new Promise(resolve => setTimeout(resolve, 20));
    try {
      await Promise.race([fetch(`http://127.0.0.1:${port}/`), stopped]);
      return { child, runtime };
    } catch (error) {
      if (attempt === 49) throw error;
    }
  }
  throw new Error('nginx did not become ready');
}

async function stopNginx(server) {
  server.child.kill('SIGQUIT');
  await new Promise(resolve => server.child.once('exit', resolve));
}

async function port() {
  const server = http.createServer();
  const value = await listen(server);
  await close(server);
  return value;
}

test('the local static server isolates documents, workers, routes and assets', async () => {
  const webRoot = await fixture();
  const server = createStaticServer({ staticRoot: webRoot });
  const serverPort = await listen(server);
  const base = `http://127.0.0.1:${serverPort}`;
  try {
    await assertHeaders(base);
    await assertIsolation(base);
  } finally {
    await close(server);
  }
});

test('the deployment nginx public listener is isolated while admin listeners are not', async () => {
  const webRoot = await fixture();
  const publicPort = await port();
  const adminPort = await port();
  const privateAdminPort = await port();
  let config = await readFile(join(root, 'deploy/nginx.conf'), 'utf8');
  const runtime = await temporaryDirectory('monaserver-deploy-nginx-');
  await mkdir(join(runtime, 'tmp'));
  config = config
    .replace('pid /tmp/nginx.pid;', `pid ${runtime}/nginx.pid;`)
    .replaceAll('/tmp/nginx/', `${runtime}/tmp/`)
    .replace('listen 8081;', `listen ${publicPort};`)
    .replace('listen 8082;', `listen ${adminPort};`)
    .replace('listen 8083;', `listen ${privateAdminPort};`)
    .replace('/srv/web', webRoot)
    .replace('server rustfs:9000;', 'server 127.0.0.1:9;');
  const server = await startNginx(config, publicPort);
  try {
    const base = `http://127.0.0.1:${publicPort}`;
    await assertHeaders(base);
    await assertIsolation(base);
    for (const admin of [adminPort, privateAdminPort]) {
      const response = await fetch(`http://127.0.0.1:${admin}/`);
      assert.equal(response.headers.get('cross-origin-opener-policy'), null);
      assert.equal(response.headers.get('cross-origin-embedder-policy'), null);
    }
  } finally {
    await stopNginx(server);
  }
});

test('the Flutter container nginx isolates every static response', async () => {
  const webRoot = await fixture();
  const webPort = await port();
  let config = await readFile(join(root, 'flutter/docker/nginx.conf'), 'utf8');
  config = config.replace('listen       80;', `listen       ${webPort};`).replace('/usr/share/nginx/html', webRoot);
  const server = await startNginx(config, webPort);
  try {
    const base = `http://127.0.0.1:${webPort}`;
    await assertHeaders(base);
    await assertIsolation(base);
  } finally {
    await stopNginx(server);
  }
});

test('the worktree development renderer isolates its generated web host', async () => {
  const webRoot = await fixture();
  const webPort = await port();
  const runtime = await temporaryDirectory('monaserver-dev-nginx-');
  const master = join(runtime, 'nginx.conf');
  const snippet = join(runtime, 'worktrees', 'test.conf');
  const environment = {
    ...process.env,
    DEV_NGINX_RUNTIME_DIR: runtime,
    DEV_NGINX_PORT: String(webPort),
    DEV_SLUG: 'isolation-test',
    DEV_DOMAIN_SUFFIX: 'localhost',
    DEV_WEB_HOST: 'localhost',
    DEV_WEB_ROOT: webRoot,
    DEV_API_PORT: '9',
    DEV_STORAGE_PORT: '9',
  };
  const run = (script, argument) => new Promise((resolve, reject) => {
    const child = spawn(script, [argument], { env: environment });
    child.once('exit', code => code === 0 ? resolve() : reject(new Error(`${script} exited ${code}`)));
  });
  await run(join(root, 'scripts/dev/render-nginx-master-config.sh'), master);
  await run(join(root, 'scripts/dev/render-nginx-worktree-config.sh'), snippet);
  const config = await readFile(master, 'utf8');
  const server = await startNginx(config, webPort);
  try {
    const base = `http://localhost:${webPort}`;
    await assertHeaders(base);
    await assertIsolation(base);
  } finally {
    await stopNginx(server);
  }
});
