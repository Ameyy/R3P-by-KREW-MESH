/**
 * R3P Fitness Service Worker — High Performance Offline PWA Engine
 * Built in accordance with PWABuilder Standard Service Worker Specifications
 * Features:
 * - Cache-first & Stale-while-revalidate for static assets
 * - Network-first for dynamic cloud data
 * - Offline navigation fallback to cached App Shell
 * - Background Sync & Push Notification event listeners
 * - Zero design/UI changes
 */

const CACHE_NAME = 'r3p-pwa-v2.0';

// Core static assets representing the complete offline App Shell
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/css/theme.css',
  '/js/supabase_client.js',
  '/js/db.js',
  '/js/main.js',
  '/assets/icon-192.png',
  '/assets/icon-512.png',
  '/assets/icon-maskable-512.png',
  '/assets/apple-touch-icon.png',
  '/assets/r3p_icon.png',
  '/assets/r3p_logo_base.png',
  '/assets/r3p_logo_orange.png',
  '/assets/login_hero.png',
  '/assets/shortcut-checkin.png',
  '/assets/shortcut-workout.png',
  '/assets/shortcut-payments.png',
  '/assets/screenshot-mobile.png',
  '/assets/screenshot-wide.png'
];

// 1. Install Event — Pre-cache static App Shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Pre-caching offline app shell');
      return cache.addAll(STATIC_ASSETS).catch((err) => {
        console.warn('[SW] Non-critical cache addAll item failed:', err);
      });
    }).then(() => self.skipWaiting())
  );
});

// 2. Activate Event — Immediately claim clients and purge stale caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            console.log('[SW] Deleting deprecated cache version:', key);
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// 3. Fetch Event — Network-first with cache fallback & stale-while-revalidate
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);

  // Ignore non-http schemes (extensions, devtools, chrome://)
  if (!url.protocol.startsWith('http')) return;

  // Supabase REST or dynamic API endpoints: Always Network-First
  if (url.hostname.includes('supabase.co')) {
    event.respondWith(
      fetch(event.request).catch(() => caches.match(event.request))
    );
    return;
  }

  // HTML Page Navigation: Network-First with Offline App Shell Fallback
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const clone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          }
          return networkResponse;
        })
        .catch(() => {
          console.log('[SW] Offline navigation: serving cached index.html');
          return caches.match('/index.html') || caches.match('/');
        })
    );
    return;
  }

  // Static Assets (CSS, JS, Images, Fonts): Stale-While-Revalidate
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      const networkFetch = fetch(event.request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const clone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          }
          return networkResponse;
        })
        .catch(() => cachedResponse);

      return cachedResponse || networkFetch;
    })
  );
});

// 4. Background Sync (PWABuilder Standard Offline Queue Event)
self.addEventListener('sync', (event) => {
  if (event.tag === 'r3p-offline-sync') {
    event.waitUntil(
      self.clients.matchAll().then((clients) => {
        clients.forEach((client) => {
          client.postMessage({ type: 'TRIGGER_OFFLINE_SYNC' });
        });
      })
    );
  }
});

// 5. Push Notification Handler (Native Push capability)
self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : { title: 'R3P Fitness', body: 'New notification from your gym club' };
  const options = {
    body: data.body,
    icon: '/assets/icon-192.png',
    badge: '/assets/icon-192.png',
    vibrate: [100, 50, 100],
    data: { url: data.url || '/' }
  };
  event.waitUntil(
    self.registration.showNotification(data.title || 'R3P Fitness', options)
  );
});

// 6. Notification Click Handler — Focus or open app
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url === '/' && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(event.notification.data?.url || '/');
      }
    })
  );
});
