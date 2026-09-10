import { createReadStream, statSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, extname, join, resolve } from 'node:path';
import http from 'node:http';

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

function safeStaticPath(staticRoot, requestUrl) {
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(requestUrl, 'http://localhost').pathname);
  } catch {
    return null;
  }
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

export function createStaticServer({ staticRoot }) {
  const root = fileURLToPath(
    staticRoot instanceof URL ? staticRoot : pathToFileURL(staticRoot),
  );
  return http.createServer((request, response) => {
    serveStatic(request, response, root);
  });
}

function run() {
  const staticRoot = resolve(
    process.env.WEB_ROOT ?? resolve(dirname(fileURLToPath(import.meta.url)), '../build/web'),
  );
  const port = Number(process.env.PORT ?? 4173);
  const server = createStaticServer({ staticRoot });
  server.listen(port, '127.0.0.1', () => {
    console.log(`Flutter web server listening on http://127.0.0.1:${port}`);
    console.log(`Serving static web files from ${staticRoot}`);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  run();
}
