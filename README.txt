Smart POS — ไฟล์สำหรับ GitHub Pages (วางทั้งหมดในโฟลเดอร์เดียวกัน / ราก repo)

ไฟล์ที่ต้องมี
  index.html               แอปหลัก (ไฟล์เดียว)
  sw.js                    service worker (เปิดแอปได้เมื่อออฟไลน์)
  manifest.webmanifest     ไฟล์ติดตั้งเป็นแอป (PWA)
  icon.svg                 ไอคอนแอป
  SMART-POS-SETUP.sql      ฐานข้อมูล Supabase (รันครั้งเดียวใน SQL Editor)

ขั้นตอน
1) สร้าง repo บน GitHub แล้วอัปโหลดไฟล์ 4 รายการแรก (ไม่ต้องอัปโหลด .sql)
2) Settings > Pages > Source: Deploy from a branch > main / (root) แล้ว Save
3) เปิด https://<user>.github.io/<repo>/ (หรือ <user>.github.io ถ้าเป็น repo ชื่อนั้น)
4) สร้างโปรเจกต์ Supabase ใหม่ แล้วรัน SMART-POS-SETUP.sql ทั้งไฟล์ใน SQL Editor
5) Authentication > Users > Add user (ติ๊ก Auto Confirm) แล้วเปิดแอป กรอก URL และ anon key ของโปรเจกต์
6) เข้าสู่ระบบด้วยบัญชีนั้น แล้วตั้งเจ้าของร้าน

ข้อควรรู้
- ไฟล์ .sql อื่นๆ ที่เคยทำ (POS_fresh_install.sql, 003–006, ALL_IN_ONE.sql ฯลฯ) เป็นของระบบ "hardware-pos" คนละชุด ห้ามใช้กับแอปนี้
- ทุกครั้งที่อัปเดต index.html ให้เพิ่มเลขเวอร์ชันใน sw.js (ค่า const V) เพื่อให้เบราว์เซอร์โหลดของใหม่
