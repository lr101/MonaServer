import assert from 'node:assert/strict';
import { once } from 'node:events';
import http from 'node:http';
import { afterEach, test } from 'node:test';

import { createDevServer, normalizeUpstream } from './dev_server.mjs';

const servers = [];

afterEach(async () => {
  await Promise.all(
    servers.splice(0).map(async (server) => {
      server.close();
      await once(server, 'close');
    }),
  );
});

test('rejects an upstream without an HTTP(S) origin', () => {
  assert.throws(
    () => normalizeUpstream('file:///tmp/backend'),
    /HTTP or HTTPS origin/,
  );
  assert.throws(
    () => normalizeUpstream('https://api.example.test/path'),
    /origin without a path/,
  );
});

test('proxies API method, query, body, headers, and upstream status', async () => {
  const upstream = http.createServer((request, response) => {
    let body = '';
    request.setEncoding('utf8');
    request.on('data', (chunk) => (body += chunk));
    request.on('end', () => {
      assert.equal(request.method, 'POST');
      assert.equal(request.url, '/api/v3/batch?cursor=next');
      assert.equal(request.headers.authorization, 'Bearer test-token');
      assert.equal(body, '{"requests":[]}');
      response.writeHead(422, { 'content-type': 'application/json' });
      response.end('{"error":"invalid"}');
    });
  });
  upstream.listen(0, '127.0.0.1');
  await once(upstream, 'listening');
  servers.push(upstream);
  const upstreamAddress = upstream.address();

  const proxy = createDevServer({
    staticRoot: new URL('../build/web/', import.meta.url),
    upstream: `http://127.0.0.1:${upstreamAddress.port}`,
  });
  proxy.listen(0, '127.0.0.1');
  await once(proxy, 'listening');
  servers.push(proxy);
  const proxyAddress = proxy.address();

  const result = await new Promise((resolve, reject) => {
    const request = http.request(
      {
        hostname: '127.0.0.1',
        port: proxyAddress.port,
        path: '/api/v3/batch?cursor=next',
        method: 'POST',
        headers: {
          Authorization: 'Bearer test-token',
          'Content-Type': 'application/json',
        },
      },
      (response) => {
        let body = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => (body += chunk));
        response.on('end', () => resolve({ status: response.statusCode, body }));
      },
    );
    request.on('error', reject);
    request.end('{"requests":[]}');
  });

  assert.deepEqual(result, { status: 422, body: '{"error":"invalid"}' });
});

test('does not turn a missing static asset into the Flutter shell', async () => {
  const proxy = createDevServer({
    staticRoot: new URL('../build/web/', import.meta.url),
    upstream: 'http://127.0.0.1:8181',
  });
  proxy.listen(0, '127.0.0.1');
  await once(proxy, 'listening');
  servers.push(proxy);
  const address = proxy.address();

  const result = await new Promise((resolve, reject) => {
    http.get(
      {
        hostname: '127.0.0.1',
        port: address.port,
        path: '/missing.js',
      },
      (response) => {
        response.resume();
        response.on('end', () => resolve(response.statusCode));
      },
    ).on('error', reject);
  });

  assert.equal(result, 404);
});

test('serves module and Wasm assets with browser-compatible MIME types', async () => {
  const proxy = createDevServer({
    staticRoot: new URL('../build/web/', import.meta.url),
    upstream: 'http://127.0.0.1:8181',
  });
  proxy.listen(0, '127.0.0.1');
  await once(proxy, 'listening');
  servers.push(proxy);
  const address = proxy.address();

  const getHeaders = (path) =>
    new Promise((resolve, reject) => {
      http.get(
        { hostname: '127.0.0.1', port: address.port, path },
        (response) => {
          response.resume();
          response.on('end', () => resolve(response.headers));
        },
      ).on('error', reject);
    });

  const moduleHeaders = await getHeaders('/main.dart.mjs');
  assert.match(moduleHeaders['content-type'], /^application\/javascript/);
  const wasmHeaders = await getHeaders('/main.dart.wasm');
  assert.equal(wasmHeaders['content-type'], 'application/wasm');
});
