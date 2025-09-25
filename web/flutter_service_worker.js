'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {".well-known/apple-app-site-association": "7f2c371192a52373dde9f3e3dbb023f7",
".well-known/assetlinks.json": "fdcb1cb0c161234946ce67c34ec154b5",
"admin/assets/AssetManifest.bin": "e73d96c2f1756ded20aab0d1436cb105",
"admin/assets/AssetManifest.bin.json": "210f95bf98d7325abae4aa43fdf934b8",
"admin/assets/AssetManifest.json": "cc9766218ca77b6e2b6048ce1d92c392",
"admin/assets/assets/login_bg_illustration.png": "6fc453c9340b7bb9280b72be25fb0c91",
"admin/assets/assets/logo.png": "6fc453c9340b7bb9280b72be25fb0c91",
"admin/assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"admin/assets/fonts/MaterialIcons-Regular.otf": "c71c3f7d536988067e7fc83322049ef1",
"admin/assets/NOTICES": "1825add8d5d7d0b029ceb94440083c03",
"admin/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"admin/assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"admin/assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"admin/canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"admin/canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"admin/canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"admin/canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"admin/canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"admin/canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"admin/canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"admin/canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"admin/canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"admin/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"admin/firebase-messaging-sw.js": "e5b5983c42676b016c2bf7eb9f2951cf",
"admin/flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"admin/flutter_bootstrap.js": "f5213796d5d91662291f76be3b527412",
"admin/icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"admin/icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"admin/icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"admin/icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"admin/index.html": "8f9a05c603284a6a54188a3776b73ae3",
"admin/main.dart.js": "a14d0d2bc7cf81b77c18803d2e931bc8",
"admin/manifest.json": "34f4bd367f5bf7a13207a7014b03c385",
"admin/version.json": "65aa28a9b5c932a481a8e2aee85d8856",
"app-release.apk": "69b47457b7a6413f3ffb5fe4fcd43e26",
"assets/AssetManifest.bin": "383ca4d2bf6366a8f4824ce43bf83cb6",
"assets/AssetManifest.bin.json": "2ef38d1229f8c70a05513e5b35407a38",
"assets/AssetManifest.json": "87dde8478f5af7aec766317e8ffc5e53",
"assets/assets/app_icon_fixed.png": "5da031c2161d6dcf62c6d419d90bcbc4",
"assets/assets/fonts/DancingScript-VariableFont_wght.ttf": "6c13f0a369bac247a279351b7338eaf0",
"assets/assets/fonts/OFL.txt": "6dc416454d13ea7df5dc67abc37f34ce",
"assets/assets/fonts/README.txt": "ed7e1c5918abc8801d59f1c0ee0f8341",
"assets/assets/images/clothing.jpg": "1c7f48dc138e2358973274779fd6fbc0",
"assets/assets/images/electronics.jpg": "6fb6801c2099acbe415b31671783508a",
"assets/assets/images/food.jpg": "e7aeee598379ac3179f3d30f36bd8416",
"assets/assets/images/other.jpg": "1ebb6b08baa9b3f251940b8b41bc100d",
"assets/assets/logo.png": "6fc453c9340b7bb9280b72be25fb0c91",
"assets/assets/sounds/notification.mp3": "feb29173be911eeaa2c1312491acc565",
"assets/assets/splash_logo.png": "f0f8c4683d3b454283b909bb9da418f5",
"assets/assets/svg/clothing.svg": "7d5bb036fb35ced645fe4e5afb11bf55",
"assets/assets/svg/electronics.svg": "373c7012c668a0e016023763a5c5edf8",
"assets/assets/svg/food.svg": "bb89a1c67723195671163351317be9d1",
"assets/assets/svg/other.svg": "b6fdd036df347b7161fdf5def28be3cf",
"assets/FontManifest.json": "a42c0dfbd5e2b7d8b7eae5ff2b08e107",
"assets/fonts/MaterialIcons-Regular.otf": "4775ab361548f9f4ad23d41d413cdff4",
"assets/NOTICES": "3e869c346d9936d4c1110e1e9102555a",
"assets/packages/awesome_notifications/test/assets/images/test_image.png": "c27a71ab4008c83eba9b554775aa12ca",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "d7d83bd9ee909f8a9b348f56ca7b68c6",
"assets/packages/golden_toolkit/fonts/Roboto-Regular.ttf": "ac3f799d5bbaf5196fab15ab8de8431c",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"clear_sw.html": "30df8780658c11368d5b5e9524ee9cb3",
"debug.html": "00bb2c151595478ec99f522c70045963",
"debug_splash.html": "997622646132bfd3dd5fa395beb28803",
// removed PHP proxy; direct GitHub link used from download.html
"download.html": "9d464f8906fb78559c5b5d12b482beb7",
"favicon.png": "ed131d3cf116a64f521276ae3efb25b6",
"fcm-test.html": "5efde58e2d7542fd6b57e4bfc8d5da68",
"firebase-messaging-sw.js": "b744f8e73bf7909cfd3c3761b10d8cc2",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"flutter_bootstrap.js": "453eed5a02ea7ee71f7851d8fe8f1af9",
"flutter_init.js": "41bd9ea849fc6fa1dc49b9b407c29f7e",
"flutter_test.html": "60491efee18bf1e1bc58a124f4d2840e",
"icons/Icon-192.png": "e8b0226e1a0276a0992a39b6f88b0b1c",
"icons/Icon-512.png": "a0efd1e8d4cbef420f5954191af194bb",
"icons/Icon-maskable-192.png": "e8b0226e1a0276a0992a39b6f88b0b1c",
"icons/Icon-maskable-512.png": "a0efd1e8d4cbef420f5954191af194bb",
"index.html": "c4d2adf2348c916fec36d2d5c8b3c759",
"/": "c4d2adf2348c916fec36d2d5c8b3c759",
"main.dart.js": "cebb0568cc54c5654db95f4711f88ea7",
"manifest.json": "9708949d53885762b4e833e0865c42c8",
"performance_optimizer.js": "aa7403accdeed60b3653ed5adb443520",
"product_schema_template.html": "08c6fc91656e87765034e4ef62ced0d1",
"reset-password.html": "a9f714856aa42db80500ece644eeb62e",
"sitemap.xml": "b265011db74cdeebb4daee8bc313659b",
"version.json": "0626ac86625bf006426b13ab20bdf9a0",
"web.config": "fee63793bee04cf45dd4b2cf4e9e715c"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
