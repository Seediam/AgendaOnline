const CACHE_NAME="nosso-tempo-v5-20260820";
const ASSETS=["./","./index.html","./style.css","./app.js","./manifest.webmanifest","./icon.svg"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(CACHE_NAME).then(c=>c.addAll(ASSETS)));self.skipWaiting()});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE_NAME).map(k=>caches.delete(k)))));self.clients.claim()});
self.addEventListener("fetch",e=>{
  if(e.request.method!=="GET")return;
  const u=new URL(e.request.url);
  if(u.pathname.endsWith("/config.js")||u.hostname.includes("supabase.co")||u.hostname.includes("open-meteo.com")){
    e.respondWith(fetch(e.request));return;
  }
  e.respondWith(fetch(e.request).then(r=>{
    if(r.ok&&u.origin===self.location.origin)caches.open(CACHE_NAME).then(c=>c.put(e.request,r.clone()));
    return r;
  }).catch(()=>caches.match(e.request).then(x=>x||caches.match("./index.html"))));
});
