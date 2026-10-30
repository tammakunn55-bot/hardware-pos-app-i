# Smart POS V9.65

1. สำรองไฟล์บน GitHub ก่อน
2. แทนที่ `index.html`, `sw.js`, `manifest.webmanifest`, `icon.svg` ตามชุดนี้
3. ไม่ต้องรัน `SMART-POS-SETUP-v2.sql` ซ้ำ เพราะรอบนี้แก้เฉพาะ frontend และ service worker
4. Deploy GitHub Pages แล้วเปิดแอปออนไลน์เพื่อให้ Service Worker `pos-v17` ติดตั้ง
5. เข้าระบบแล้วใช้เมนูดึงข้อมูลจากคลาวด์ ตรวจจำนวนสินค้าที่โหลดกับจำนวนแถวใน Supabase
6. ทดสอบรูปสินค้า 1 รายการ แล้วเปิดจากอุปกรณ์อีกเครื่อง

อย่าลบข้อมูล LocalStorage, คิวซิงก์ หรือไฟล์ Storage ระหว่างทดสอบ
