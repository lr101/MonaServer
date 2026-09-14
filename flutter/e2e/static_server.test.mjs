import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { once } from 'node:events';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import http from 'node:http';
import { afterEach, test } from 'node:test';

import { createStaticServer } from './static_server.mjs';

const servers = [];
const roots = [];

afterEach(async () => {
  await Promise.all(
    servers.splice(0).map(async (server) => {
      server.close();
      await once(server, 'close');
    }),
  );
  await Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true })));
});

async function startStaticServer() {
  const root = await mkdtemp(join(tmpdir(), 'mona-static-'));
  roots.push(root);
  await mkdir(join(root, 'assets'));
  await writeFile(join(root, 'index.html'), '<main>app shell</main>');
  await writeFile(join(root, 'assets', 'app.js'), 'console.log("app");');

  const server = createStaticServer({ staticRoot: root });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  servers.push(server);
  return server.address();
}

function get(address, path) {
  return new Promise((resolve, reject) => {
    http.get(
      { hostname: address.address, port: address.port, path },
      (response) => {
        let body = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => (body += chunk));
        response.on('end', () => resolve({ status: response.statusCode, body }));
      },
    ).on('error', reject);
  });
}

test('serves static assets and falls back to the Flutter shell for routes', async () => {
  const address = await startStaticServer();

  assert.deepEqual(await get(address, '/assets/app.js'), {
    status: 200,
    body: 'console.log("app");',
  });
  assert.deepEqual(await get(address, '/groups/123'), {
    status: 200,
    body: '<main>app shell</main>',
  });
});

test('returns 404 for missing assets instead of serving the shell', async () => {
  const address = await startStaticServer();

  assert.deepEqual(await get(address, '/missing.js'), {
    status: 404,
    body: 'Not found',
  });
});
