// Service worker: permite instalar la app y que abra rápido.
// Las páginas siempre se piden primero a internet (para tener la versión nueva);
// si no hay señal, se usa la copia guardada. Supabase nunca se guarda en caché.
const CACHE = 'cafe-express-v4';
const ARCHIVOS = ['./', './index.html', './puesto.html', './dueno.html', './estilos.css', './config.js', './api.js',
  './iconos/icono-192.png', './iconos/icono-512.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(ARCHIVOS)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(k => Promise.all(k.filter(x => x !== CACHE).map(x => caches.delete(x)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  e.respondWith(fetch(e.request).then(r => { const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); return r; })
    .catch(() => caches.match(e.request, { ignoreSearch: true })));
});
