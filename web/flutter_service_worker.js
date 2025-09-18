// Production-ready offline shell for marketplace
// Version based on app version and timestamp for automatic cache busting
const APP_VERSION = '1.0.0+3'; // Should match pubspec.yaml
const BUILD_TIMESTAMP = Date.now(); // Unique per build
const CACHE_VERSION = `${APP_VERSION}-${BUILD_TIMESTAMP}`;

const STATIC_CACHE = `mzansi-static-${CACHE_VERSION}`;
const RUNTIME_PAGES = `mzansi-pages-${CACHE_VERSION}`;
const RUNTIME_ASSETS = `mzansi-assets-${CACHE_VERSION}`;
const RUNTIME_API = `mzansi-api-${CACHE_VERSION}`;
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
    // Clean up old caches - more aggressive cleanup
    const keys = await caches.keys();
    const validCaches = [STATIC_CACHE, RUNTIME_PAGES, RUNTIME_ASSETS, RUNTIME_API];
    
    // Delete all caches that don't match current version
    await Promise.all(
      keys.filter((k) => !validCaches.includes(k))
          .map((k) => {
            console.log('🗑️ Deleting old cache:', k);
            return caches.delete(k);
          })
    );
    
    // Clear browser storage on version change
    try {
      const currentCacheKey = `app_cache_version_${CACHE_VERSION}`;
      const lastVersion = await getStoredVersion();
      
      if (lastVersion && lastVersion !== CACHE_VERSION) {
        console.log('🔄 Version change detected, clearing browser storage');
        await clearBrowserStorage();
      }
      
      await setStoredVersion(CACHE_VERSION);
    } catch (e) {
      console.warn('⚠️ Error managing version storage:', e);
    }
    
    await self.clients.claim();
    
    // Enable navigation preload for faster page loads
    if (self.registration.navigationPreload) {
      await self.registration.navigationPreload.enable();
    }
    
    // Notify clients of update
    self.clients.matchAll().then(clients => {
      clients.forEach(client => {
        client.postMessage({
          type: 'CACHE_UPDATED',
          version: CACHE_VERSION
        });
      });
    });
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
  
  if (event.data && event.data.type === 'CLEAR_CACHE') {
    // Force clear all caches
    caches.keys().then(keys => {
      return Promise.all(keys.map(key => caches.delete(key)));
    }).then(() => {
      self.clients.matchAll().then(clients => {
        clients.forEach(client => {
          client.postMessage({ type: 'CACHE_CLEARED' });
        });
      });
    });
  }
});

// Helper functions for version storage management
async function getStoredVersion() {
  try {
    const db = await openDB();
    const tx = db.transaction(['versions'], 'readonly');
    const store = tx.objectStore('versions');
    const result = await store.get('current_version');
    return result?.version;
  } catch (e) {
    return null;
  }
}

async function setStoredVersion(version) {
  try {
    const db = await openDB();
    const tx = db.transaction(['versions'], 'readwrite');
    const store = tx.objectStore('versions');
    await store.put({ id: 'current_version', version: version, timestamp: Date.now() });
  } catch (e) {
    console.warn('Failed to store version:', e);
  }
}

async function openDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('mzansi_cache_db', 1);
    
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains('versions')) {
        db.createObjectStore('versions', { keyPath: 'id' });
      }
    };
  });
}

async function clearBrowserStorage() {
  try {
    // Clear localStorage
    if (typeof localStorage !== 'undefined') {
      localStorage.clear();
    }
    
    // Clear sessionStorage  
    if (typeof sessionStorage !== 'undefined') {
      sessionStorage.clear();
    }
    
    console.log('✅ Browser storage cleared');
  } catch (e) {
    console.warn('⚠️ Error clearing browser storage:', e);
  }
}


