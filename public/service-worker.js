/**
 * CA Small Claims PWA Service Worker
 * Provides offline support for form filling with intelligent caching
 */

const CACHE_VERSION = 'v2';
const STATIC_CACHE = `ca-small-claims-static-${CACHE_VERSION}`;
const DYNAMIC_CACHE = `ca-small-claims-dynamic-${CACHE_VERSION}`;
const FORM_CACHE = `ca-small-claims-forms-${CACHE_VERSION}`;

// Static assets to cache on install
const STATIC_ASSETS = [
  '/',
  '/manifest.json',
  '/icon.png',
  '/icon.svg',
  '/offline.html'
];

// Patterns for different cache strategies
const CACHE_STRATEGIES = {
  // Static assets - cache first, network fallback
  static: [
    /\.(js|css|woff2?|ttf|eot)$/,
    /\/assets\//
  ],
  // Form pages - network first, cache fallback
  forms: [
    /\/forms\/[A-Z0-9-]+/i
  ],
  // API calls - network only, don't cache
  networkOnly: [
    /\/api\//,
    /\.json$/
  ]
};

// Install event - cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => {
        console.log('[SW] Caching static assets');
        return cache.addAll(STATIC_ASSETS.filter(asset => !asset.includes('offline.html')));
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => {
              return name.startsWith('ca-small-claims-') &&
                     name !== STATIC_CACHE &&
                     name !== DYNAMIC_CACHE &&
                     name !== FORM_CACHE;
            })
            .map((name) => {
              console.log('[SW] Deleting old cache:', name);
              return caches.delete(name);
            })
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch event - apply caching strategies
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests (form submissions handled by IndexedDB)
  if (request.method !== 'GET') {
    return;
  }

  // Skip cross-origin requests
  if (url.origin !== location.origin) {
    return;
  }

  // Determine caching strategy based on URL
  if (matchesPattern(url.pathname, CACHE_STRATEGIES.networkOnly)) {
    // Network only - no caching
    return;
  }

  if (matchesPattern(url.pathname, CACHE_STRATEGIES.forms)) {
    // Forms - network first with cache fallback
    event.respondWith(networkFirst(request, FORM_CACHE));
    return;
  }

  if (matchesPattern(url.pathname, CACHE_STRATEGIES.static)) {
    // Static assets - cache first
    event.respondWith(cacheFirst(request, STATIC_CACHE));
    return;
  }

  // Default - stale while revalidate for HTML pages
  if (request.headers.get('Accept')?.includes('text/html')) {
    event.respondWith(staleWhileRevalidate(request, DYNAMIC_CACHE));
    return;
  }

  // Everything else - cache first with network fallback
  event.respondWith(cacheFirst(request, DYNAMIC_CACHE));
});

// Cache strategies

/**
 * Cache first - try cache, fallback to network
 */
async function cacheFirst(request, cacheName) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }

  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(cacheName);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.log('[SW] Network failed for:', request.url);
    return caches.match('/offline.html');
  }
}

/**
 * Network first - try network, fallback to cache
 */
async function networkFirst(request, cacheName) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(cacheName);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.log('[SW] Network failed, trying cache for:', request.url);
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    // Return offline page for HTML requests
    if (request.headers.get('Accept')?.includes('text/html')) {
      return caches.match('/offline.html');
    }
    return new Response('Offline', { status: 503 });
  }
}

/**
 * Stale while revalidate - return cache immediately, update in background
 */
async function staleWhileRevalidate(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cachedResponse = await cache.match(request);

  const fetchPromise = fetch(request)
    .then((networkResponse) => {
      if (networkResponse.ok) {
        cache.put(request, networkResponse.clone());
      }
      return networkResponse;
    })
    .catch(() => cachedResponse);

  return cachedResponse || fetchPromise;
}

/**
 * Check if URL matches any pattern in the list
 */
function matchesPattern(pathname, patterns) {
  return patterns.some((pattern) => {
    if (pattern instanceof RegExp) {
      return pattern.test(pathname);
    }
    return pathname.includes(pattern);
  });
}

// Message handler for cache management
self.addEventListener('message', (event) => {
  const { type, payload } = event.data || {};

  switch (type) {
    case 'SKIP_WAITING':
      self.skipWaiting();
      break;

    case 'CACHE_FORM':
      // Pre-cache a specific form page
      if (payload?.url) {
        caches.open(FORM_CACHE)
          .then((cache) => cache.add(payload.url))
          .then(() => {
            event.ports[0]?.postMessage({ success: true });
          })
          .catch((error) => {
            event.ports[0]?.postMessage({ success: false, error: error.message });
          });
      }
      break;

    case 'CLEAR_CACHE':
      Promise.all([
        caches.delete(STATIC_CACHE),
        caches.delete(DYNAMIC_CACHE),
        caches.delete(FORM_CACHE)
      ]).then(() => {
        event.ports[0]?.postMessage({ success: true });
      });
      break;

    case 'GET_CACHE_SIZE':
      getCacheSize().then((size) => {
        event.ports[0]?.postMessage({ size });
      });
      break;
  }
});

/**
 * Calculate total cache size
 */
async function getCacheSize() {
  const cacheNames = await caches.keys();
  let totalSize = 0;

  for (const cacheName of cacheNames) {
    if (cacheName.startsWith('ca-small-claims-')) {
      const cache = await caches.open(cacheName);
      const keys = await cache.keys();
      // Estimate size (actual size calculation requires reading all responses)
      totalSize += keys.length * 50000; // Rough estimate: 50KB per cached item
    }
  }

  return totalSize;
}
