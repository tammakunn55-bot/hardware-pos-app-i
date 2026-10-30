// Service worker: ให้แอปเปิดได้แม้ไม่มีอินเทอร์เน็ต (วางไฟล์นี้ไว้โฟลเดอร์เดียวกับ index.html)
// เปลี่ยนเลข V ทุกครั้งที่แก้ index.html / รายการไลบรารี เพื่อให้เครื่องหน้าร้านโหลดเวอร์ชันใหม่
const V = 'pos-v16';
// ต้องตรงกับ URL ใน <script src> ของ index.html ทุกตัว (ไม่งั้นเปิดออฟไลน์ครั้งแรกไม่ได้)
const SHELL = [
  './', './manifest.webmanifest', './icon.svg',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4',
  'https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js',
  'https://cdn.jsdelivr.net/npm/exceljs@4.4.0/dist/exceljs.min.js'
];
// เก็บทีละไฟล์: ถ้าไฟล์ไหนโหลดไม่ได้ ไม่ทำให้การติดตั้ง service worker ล้มทั้งชุด
self.addEventListener('install', e => e.waitUntil(
  caches.open(V).then(c => Promise.all(SHELL.map(u => c.add(u).catch(err => console.warn('precache skip', u, err)))))
    .then(() => self.skipWaiting())));
self.addEventListener('activate', e => e.waitUntil(
  caches.keys().then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => {
  const r = e.request; if (r.method !== 'GET') return;
  const u = new URL(r.url);
  if (u.hostname.endsWith('.supabase.co') && !u.pathname.startsWith('/storage/')) return;   // ข้อมูล/API: ใช้เครือข่ายเสมอ
  if (r.mode === 'navigate') {
    if (!/(index\.html|app\.html|\/)$/.test(u.pathname)) return;
    e.respondWith(fetch(r).then(res => { const cp = res.clone(); caches.open(V).then(c => c.put('./', cp)); return res; })
      .catch(() => caches.match('./')));
    return;
  }
  if (r.destination === 'image' || u.pathname.includes('/storage/')) {       // รูปสินค้า: ใช้ cache เดิมทันทีและอัปเดต cache จากเครือข่ายสำหรับการเปิดครั้งถัดไป
    e.respondWith(caches.open(V).then(c => c.match(r).then(m => {
      const net = fetch(r).then(res => { c.put(r, res.clone()); return res; }).catch(() => m);
      return m || net;
    })));
    return;
  }
  e.respondWith(caches.match(r).then(m => m || fetch(r).then(res => { const cp = res.clone(); caches.open(V).then(c => c.put(r, cp)); return res; })));
});
