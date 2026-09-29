const CACHE_NAME = '__OFFLINE_CACHE_NAME__';
const CACHE_PREFIX = 'stickit-app-';
const ASSETS = __OFFLINE_ASSETS__;
const ASSET_PATHS = new Set(ASSETS);

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    for (let index = 0; index < ASSETS.length; index += 8) {
      const batch = ASSETS.slice(index, index + 8).map((path) =>
        new Request(new URL(path, self.registration.scope), { cache: 'reload' }));
      await cache.addAll(batch);
    }
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME) {
        await caches.delete(name);
      }
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (/^\/(?:api|public|monaserver|swagger-ui)(?:\/|$)/.test(url.pathname) ||
      url.pathname === '/healthz') return;

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      const shell = await caches.match('/index.html', { cacheName: CACHE_NAME });
      return shell || fetch(request);
    })());
    return;
  }

  if (!ASSET_PATHS.has(url.pathname)) return;
  event.respondWith((async () => {
    const cached = await caches.match(url.pathname, { cacheName: CACHE_NAME });
    return cached || fetch(request);
  })());
});
