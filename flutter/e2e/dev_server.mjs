import { createReadStream, statSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, extname, join, normalize, resolve } from 'node:path';
import http from 'node:http';
import https from 'node:https';

const defaultUpstream = 'http://127.0.0.1:8181';
const hopByHopHeaders = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
]);
const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'application/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.mjs', 'application/javascript; charset=utf-8'],
  ['.wasm', 'application/wasm'],
  ['.png', 'image/png'],
  ['.jpg', 'image/jpeg'],
  ['.jpeg', 'image/jpeg'],
  ['.gif', 'image/gif'],
  ['.svg', 'image/svg+xml'],
  ['.ico', 'image/x-icon'],
  ['.woff', 'font/woff'],
  ['.woff2', 'font/woff2'],
  ['.ttf', 'font/ttf'],
]);

export function normalizeUpstream(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error('API upstream must be an HTTP or HTTPS origin');
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error('API upstream must be an HTTP or HTTPS origin');
  }
  if (url.username || url.password || (url.pathname !== '' && url.pathname !== '/')) {
    throw new Error('API upstream must be an origin without a path or credentials');
  }
  if (url.search || url.hash) {
    throw new Error('API upstream must be an origin without a path or credentials');
  }
  return url.origin;
}

function copyResponseHeaders(source) {
  return Object.fromEntries(
    Object.entries(source).filter(([name]) => !hopByHopHeaders.has(name.toLowerCase())),
  );
}

function safeStaticPath(staticRoot, requestUrl) {
  const pathname = decodeURIComponent(new URL(requestUrl, 'http://localhost').pathname);
  const relative = pathname.replace(/^\/+/, '');
  const candidate = resolve(staticRoot, relative);
  const root = resolve(staticRoot);
  if (candidate !== root && !candidate.startsWith(`${root}/`)) return null;
  return candidate;
}

function serveStatic(request, response, staticRoot) {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.writeHead(405, { allow: 'GET, HEAD' });
    response.end();
    return;
  }

  const candidate = safeStaticPath(staticRoot, request.url);
  if (candidate == null) {
    response.writeHead(400);
    response.end('Bad request');
    return;
  }

  let file = candidate;
  try {
    if (statSync(file).isDirectory()) file = join(file, 'index.html');
    statSync(file);
  } catch {
    // Client-side routes fall back to the Flutter shell. A missing asset must
    // remain a real 404 so failed configuration and script loads are visible.
    file = extname(candidate) === '' ? join(staticRoot, 'index.html') : null;
  }

  if (file == null) {
    response.writeHead(404);
    response.end('Not found');
    return;
  }

  const contentType = contentTypes.get(extname(file).toLowerCase());
  response.writeHead(200, contentType ? { 'content-type': contentType } : {});
  if (request.method === 'HEAD') {
    response.end();
  } else {
    createReadStream(file).pipe(response);
  }
}

function proxyApi(request, response, upstream) {
  const client = upstream.protocol === 'https:' ? https : http;
  const headers = {};
  for (const [name, value] of Object.entries(request.headers)) {
    if (!hopByHopHeaders.has(name.toLowerCase()) && value !== undefined) {
      headers[name] = value;
    }
  }
  headers.host = upstream.host;

  const upstreamRequest = client.request(
    {
      protocol: upstream.protocol,
      hostname: upstream.hostname,
      port: upstream.port || undefined,
      method: request.method,
      path: request.url,
      headers,
      servername: upstream.hostname,
    },
    (upstreamResponse) => {
      response.writeHead(
        upstreamResponse.statusCode ?? 502,
        copyResponseHeaders(upstreamResponse.headers),
      );
      upstreamResponse.pipe(response);
    },
  );
  upstreamRequest.on('error', (error) => {
    if (response.headersSent) {
      response.destroy(error);
      return;
    }
    response.writeHead(502, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ error: 'API upstream unavailable' }));
  });
  request.pipe(upstreamRequest);
}

export function createDevServer({ staticRoot, upstream }) {
  const root = fileURLToPath(staticRoot instanceof URL ? staticRoot : pathToFileURL(staticRoot));
  const parsedUpstream = new URL(normalizeUpstream(upstream));
  return http.createServer((request, response) => {
    if (request.url?.startsWith('/api/')) {
      proxyApi(request, response, parsedUpstream);
    } else {
      serveStatic(request, response, root);
    }
  });
}

function run() {
  const staticRoot = resolve(process.env.WEB_ROOT ?? resolve(dirname(fileURLToPath(import.meta.url)), '../build/web'));
  const upstream = process.env.API_UPSTREAM ?? process.env.E2E_API_URL ?? defaultUpstream;
  const port = Number(process.env.PORT ?? 4173);
  const server = createDevServer({ staticRoot, upstream });
  server.listen(port, '127.0.0.1', () => {
    console.log(`Flutter web server listening on http://127.0.0.1:${port}`);
    console.log(`Proxying /api/ to ${normalizeUpstream(upstream)}`);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  run();
}
