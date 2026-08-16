/* Mine Pong offline cache.
   Bump CACHE when you publish a new build, otherwise phones that already
   installed the game keep serving the old one from disk. */
const CACHE = "minepong-v2.9.2";
const ASSETS = [
    "./",
    "./index.html",
    "./manifest.webmanifest",
    "./icon-192.png",
    "./icon-512.png",
    "./icon-512-maskable.png",
    "./apple-touch-icon.png"
];

self.addEventListener("install", (e) => {
    e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
    e.waitUntil(
        caches.keys()
            .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
            .then(() => self.clients.claim())
    );
});

// Serve from cache for speed, refresh in the background for the next launch.
// Only our own files: the online mode talks to the PeerJS signaling server and
// those requests must always go straight to the network.
self.addEventListener("fetch", (e) => {
    const url = new URL(e.request.url);
    if (e.request.method !== "GET" || url.origin !== location.origin) return;

    e.respondWith(
        caches.match(e.request).then((hit) => {
            const live = fetch(e.request)
                .then((res) => {
                    if (res && res.ok) {
                        const copy = res.clone();
                        caches.open(CACHE).then((c) => c.put(e.request, copy));
                    }
                    return res;
                })
                .catch(() => hit);
            return hit || live;
        })
    );
});
