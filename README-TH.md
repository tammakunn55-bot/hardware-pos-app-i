# Smart POS — ชุดเริ่มต้น GitHub Pages + Supabase

ชุดนี้ประกอบด้วย `index.html` สำหรับ GitHub Pages และ `SMART-POS-SETUP.sql` สำหรับสร้างโครงสร้างฐานข้อมูลและ RPC ที่หน้าเว็บเรียกใช้ โดยยึดสัญญาจากไฟล์ HTML ที่ให้มา

## 1. สร้าง Supabase ใหม่
1. สร้าง Project ใหม่สำหรับร้านนี้โดยเฉพาะ
2. เปิด **SQL Editor → New query**
3. เปิด `SMART-POS-SETUP.sql` คัดลอกทั้งหมดไปวาง แล้วกด **Run**
4. ตรวจสอบว่ารันจบโดยไม่มี error
5. ใน Supabase ไปที่ **Authentication → Providers** ตรวจว่า Email provider เปิดใช้งานอยู่
6. สร้างบัญชี Auth แรกสำหรับผู้ดูแลผ่านหน้า Authentication ของ Supabase (หรือวิธีลงชื่อเข้าใช้ที่หน้าเว็บรองรับ) ก่อนใช้ขั้นตอน bootstrap owner ของหน้าเว็บ

## 2. ตั้งค่า Storage
SQL จะสร้าง bucket `product-images` และ `delivery-notes` พร้อมนโยบาย Storage ที่ใช้กับหน้าเว็บ รูปอ่านผ่าน public URL ได้ แต่การอัปโหลด/แก้ไข/ลบต้องเป็นผู้ใช้ที่ผ่าน Supabase Auth แล้ว

## 3. เผยแพร่ GitHub Pages
1. สร้าง repository ใหม่บน GitHub
2. อัปโหลด `index.html` ไว้ที่ root ของ repository
3. ไปที่ **Settings → Pages** แล้วเลือก deploy จาก branch `main` และ folder `/ (root)`
4. เปิด URL GitHub Pages ที่ระบบให้

## 4. เชื่อมต่อ Supabase ในหน้าเว็บ
1. คัดลอก Project URL จาก **Supabase → Project Settings → API**
2. คัดลอก **publishable key / anon public key** จากหน้าเดียวกัน ห้ามใช้ `service_role` หรือ secret key ใน HTML
3. เปิดหน้าตั้งค่า Supabase ในโปรแกรม วาง Project URL และ public key แล้วบันทึก
4. ลงชื่อเข้าใช้ Supabase Auth แล้วทำขั้นตอนตั้งค่าบัญชีร้านครั้งแรกตามหน้าโปรแกรม

## ข้อควรทราบก่อนใช้ข้อมูลจริง
- ชุด SQL นี้ตั้งใจสำหรับ **Supabase project ใหม่ที่ว่าง** ไม่ใช่ migration สำหรับฐานข้อมูลเก่า เพราะ `CREATE TABLE IF NOT EXISTS` จะไม่ปรับคอลัมน์ของตารางที่มีอยู่แล้ว
- ไฟล์นี้ยังไม่ได้ทดสอบรันกับ Project Supabase ของคุณจริง จึงควรทดสอบบน project เปล่าด้วยข้อมูลตัวอย่างก่อนใช้ขายจริง โดยเฉพาะขายเชื่อ/รับชำระหนี้/คืนสินค้า/ปิดกะ
- นโยบายฐานข้อมูลอนุญาตให้ผู้ใช้ที่ลงชื่อเข้าใช้ Supabase Auth ทำงานกับข้อมูลร้านได้ทั้งหมด ตามความต้องการให้พนักงานมีสิทธิ์เท่ากัน แต่ไม่ได้แปลว่า PIN ในหน้า POS เพียงอย่างเดียวเป็นระบบยืนยันตัวตนระดับฐานข้อมูล
- GitHub Pages เป็น frontend เท่านั้น ไม่ได้ให้บริการ local server หรือระบบทำงานหลายอุปกรณ์แบบ offline โดยอัตโนมัติ
- สำรองข้อมูลก่อนเปลี่ยน SQL หรือใช้กับข้อมูลจริงเสมอ
