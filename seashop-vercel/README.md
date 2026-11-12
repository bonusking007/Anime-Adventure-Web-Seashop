# Seashop Anime Adventures Tracker

1. นำโฟลเดอร์นี้ขึ้น GitHub แล้ว Import โปรเจกต์ใน Vercel ให้ Root Directory เป็นที่อยู่ของไฟล์ vercel.json
2. ตั้ง Environment Variables ตามไฟล์ .env.example ใช้ URL และ REST Token จาก Upstash Redis ตั้ง TRACKER_API_KEY และ TRACKER_VIEW_KEY เป็นรหัสสุ่มคนละค่า
3. หลัง deploy เปิด seashop-tracker.lua ตั้ง BaseUrl เป็นโดเมนเว็บ และ TrackerKey ให้ตรงกับ TRACKER_API_KEY
4. ใช้สคริปต์กับบัญชี Roblox ที่จะส่งข้อมูล เปิดหน้า Dashboard ใส่ Roblox User ID ของบัญชีนั้นและ TRACKER_VIEW_KEY
5. สคริปต์ส่ง snapshot ทุก 20 วินาที หน้าเว็บรีเฟรชข้อมูลทุก 15 วินาที

ตัวติดตามอ่านข้อมูล LocalPlayer และข้อมูลเพชร ทอง เวฟ และรางวัลเพชร/ทองจากหน้าผลที่เกมแสดง ข้อมูลที่ไม่มีจะแสดงว่าง ระบบเก็บ snapshot ล่าสุดต่อ User ID เป็นเวลา 7 วันหลังอัปเดตล่าสุด
