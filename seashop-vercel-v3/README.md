# Seashop Anime Adventures Tracker v3

หน้าเว็บใช้เลย์เอาต์จาก Seashop Steal an Egg โดยเปลี่ยนการ์ดและหน้ารายละเอียดให้แสดงข้อมูล Anime Adventures

อัปเดตโปรเจกต์ Vercel เดิมโดยนำไฟล์ใน ZIP ไปทับในโฟลเดอร์ seashop-vercel-v3 บน GitHub รวม public/assets, public/index.html และ api/player.js ตั้ง Root Directory เป็น seashop-vercel-v3 และใช้ Environment Variables เดิมใน Production

รัน seashop-tracker.lua ในบัญชีที่จะติดตาม ตั้ง BaseUrl ให้ตรงโดเมน Vercel และ TrackerKey ให้ตรงกับ TRACKER_API_KEY เวอร์ชันก่อนยังส่งเพชร ทอง และเวฟได้ เวอร์ชันนี้ส่งรายการไอเทมเพิ่มเมื่ออ่านรายการที่แสดงในหน้าผลรอบได้ เก็บไฟล์ที่กรอกคีย์จริงไว้นอก repo

เปิด Dashboard ได้โดยตรงโดยไม่ต้องกรอก View Key ข้อมูลที่ tracker ส่งจะเปิดให้ผู้เข้าชมเว็บเห็น ส่วน tracker ยังใช้ TRACKER_API_KEY สำหรับส่งข้อมูล

เปิด Items → All ในเกม แล้วกด Sync now เพื่อบันทึกรายการกระเป๋าที่เกมสร้างไว้ใน UI หน้าเว็บจะเก็บข้อมูลล่าสุดที่ได้รับเมื่อปิดกระเป๋า แท็บรางวัลรอบล่าสุดอ่านจากหน้าผลจบรอบแยกกัน บัญชีจะค้างในรายการสูงสุด 7 วันหลังการส่งล่าสุด และขึ้นสถานะออฟไลน์เมื่อขาดอัปเดต 60 วินาที
