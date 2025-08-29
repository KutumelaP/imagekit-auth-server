// Production-ready offline shell for marketplace
const STATIC_CACHE = 'mzansi-static-v6-prod';
const RUNTIME_PAGES = 'mzansi-pages-v6-prod';
const RUNTIME_ASSETS = 'mzansi-assets-v6-prod';
const RUNTIME_API = 'mzansi-api-v6-prod';
const CORE = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter_bootstrap.js',
  '/flutter.js',
  '/flutter_init.js'
];

// Preload critical resources for faster loading
const CRITICAL_RESOURCES = [
  '/main.dart.js',
  '/canvaskit/canvaskit.js',
  '/canvaskit/profiling/canvaskit.js',
  '/canvaskit/skwasm.js'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      // Cache core files first
      const corePromise = cache.addAll(CORE);
      
      // Preload critical resources in background
      const criticalPromise = Promise.all(
        CRITICAL_RESOURCES.map(url => 
          fetch(url).then(response => {
            if (response.ok) {
              return cache.put(url, response);
            }
          }).catch(() => null)
        )
      );
      
      return Promise.all([corePromise, criticalPromise]);
    }).catch(() => null)
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(
      keys.filter((k) => ![STATIC_CACHE, RUNTIME_PAGES, RUNTIME_ASSETS, RUNTIME_API].includes(k))
          .map((k) => caches.delete(k))
    );
    await self.clients.claim();
    
    // Enable navigation preload for faster page loads
    if (self.registration.navigationPreload) {
      await self.registration.navigationPreload.enable();
    }
  })());
});

function isHTMLRequest(request) {
  return request.mode === 'navigate' ||
         (request.headers.get('accept') || '').includes('text/html');
}

function isStaticAsset(url) {
  return /\.(?:js|css|json|png|jpg|jpeg|gif|svg|webp|ico|woff2?|ttf|otf)$/.test(url.pathname) ||
         url.pathname.startsWith('/canvaskit/');
}

function isApi(url) {
  return url.hostname.endsWith('firebaseio.com') ||
         url.hostname.endsWith('googleapis.com') ||
         url.hostname.includes('imagekit.io');
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Network-first for HTML (pages) to reduce reload artifacts, fallback to cache
  if (isHTMLRequest(req)) {
    event.respondWith((async () => {
      try {
        const net = await fetch(req, { cache: 'no-store' });
        const cache = await caches.open(RUNTIME_PAGES);
        cache.put(req, net.clone());
        return net;
      } catch (e) {
        const cache = await caches.open(RUNTIME_PAGES);
        const cached = await cache.match(req) || await caches.match('/index.html');
        return cached || new Response('', { status: 503 });
      }
    })());
    return;
  }

  // Stale-while-revalidate for static assets
  if (url.origin === location.origin && isStaticAsset(url)) {
    event.respondWith((async () => {
      const cache = await caches.open(RUNTIME_ASSETS);
      const cached = await cache.match(req);
      const fetchPromise = fetch(req).then((response) => {
        cache.put(req, response.clone());
        return response;
      }).catch(() => null);
      return cached || fetchPromise || fetch(req);
    })());
    return;
  }

  // Enhanced API caching with smarter retry logic
  if (isApi(url)) {
    event.respondWith((async () => {
      const cache = await caches.open(RUNTIME_API);
      try {
        const net = await fetch(req, { 
          cache: 'no-cache',
          timeout: 8000 // 8 second timeout for API calls
        });
        if (net.status === 200) {
          cache.put(req, net.clone());
        }
        return net;
      } catch (e) {
        const cached = await cache.match(req);
        if (cached) {
          // Add offline indicator header
          const response = cached.clone();
          response.headers.set('X-Served-By', 'sw-cache');
          return response;
        }
        return new Response(JSON.stringify({
          error: 'Network unavailable',
          message: 'Please check your internet connection'
        }), { 
          status: 503,
          headers: { 'Content-Type': 'application/json' }
        });
      }
    })());
    return;
  }
});

// Allow app to trigger SW update immediately
self.addEventListener('message', (event) => {
  if (!event.data) return;
  if (event.data === 'SKIP_WAITING' || (event.data && event.data.type === 'SKIP_WAITING')) {
    self.skipWaiting();
  }
});


