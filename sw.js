/* 오프라인에서도 앱 껍데기가 뜨도록 하는 최소 캐시 */
const CACHE = "jeonpyo-v2";
const SHELL = [
  "./", "./index.html", "./config.js", "./manifest.json",
  "./assets/styles.css", "./assets/app.js", "./assets/store.js",
  "./assets/calc.js", "./assets/charts.js", "./assets/xlsx.js",
  "./assets/icon.svg"
];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET") return;
  if (url.origin !== location.origin) return;          // Supabase / CDN 요청은 그대로 통과
  e.respondWith(
    fetch(e.request)
      .then(r => { const copy = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return r; })
      .catch(() => caches.match(e.request).then(r => r || caches.match("./index.html")))
  );
});
