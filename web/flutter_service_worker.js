// Minimal offline shell for cart and store pages
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open('mzansi-static-v1').then((cache) => cache.addAll([
      '/',
      '/index.html',
      '/manifest.json',
      '/flutter_bootstrap.js'
    ]))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET') return;
  // Cache-first for static shell
  if (url.origin === location.origin) {
    event.respondWith(
      caches.match(event.request).then((resp) => resp || fetch(event.request))
    );
  }
});


