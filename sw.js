// Keeps the app working offline. Bump the version when you upload a new index.html.
const CACHE = 'mum-brain-v18';
const CORE = ['./', './index.html', './manifest.json', './icon-180.png', './icon-192.png', './icon-512.png'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  // Network first so updates show up, falling back to the saved copy when offline.
  e.respondWith(
    // Ask the server for the newest copy (skips the phone's stored copy) so updates show up straight away.
    (new URL(e.request.url).origin === self.location.origin ? fetch(e.request.url, { cache: 'no-cache', credentials: 'same-origin' }) : fetch(e.request)).then(r => {
      // iPhones refuse a page that arrived via a redirect, so hand it over as a plain copy
      const res = (r.redirected && e.request.mode === 'navigate') ? new Response(r.body, { status: r.status, statusText: r.statusText, headers: r.headers }) : r;
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(e.request, copy)).catch(() => {});
      return res;
    }).catch(() => caches.match(e.request).then(r => r || caches.match('./index.html')))
  );
});
