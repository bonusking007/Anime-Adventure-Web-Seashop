# Seashop Anime Adventures Tracker v3

หน้าเว็บใช้เลย์เอาต์จาก Seashop Steal an Egg โดยเปลี่ยนการ์ดและหน้ารายละเอียดให้แสดงข้อมูล Anime Adventures

อัปเดตโปรเจกต์ Vercel เดิมโดยนำไฟล์ใน ZIP ไปทับในโฟลเดอร์ seashop-vercel บน GitHub รวม public/assets, public/index.html และ api/player.js ตั้ง Root Directory เป็น seashop-vercel และใช้ Environment Variables เดิมใน Production

รัน seashop-tracker.lua ในบัญชีที่จะติดตาม ตั้ง BaseUrl ให้ตรงโดเมน Vercel และ TrackerKey ให้ตรงกับ TRACKER_API_KEY เวอร์ชันก่อนยังส่งเพชร ทอง และเวฟได้ เวอร์ชันนี้ส่งรายการไอเทมเพิ่มเมื่ออ่านรายการที่แสดงในหน้าผลรอบได้ เก็บไฟล์ที่กรอกคีย์จริงไว้นอก repo

เปิด Dashboard แล้วกรอก TRACKER_VIEW_KEY ครั้งเดียวต่อการเปิดหน้าเว็บ บัญชีที่ส่งข้อมูลจะแสดงอัตโนมัติและอัปเดตทุก 15 วินาที คลิกชื่อบัญชีเพื่อดูเพชร ทอง เวฟ และรางวัลล่าสุด

รายการไอเทมมาจากหน้าผลรอบล่าสุดของเกม กระเป๋าทั้งหมดไม่มีในข้อมูลที่ Tracker ส่ง บัญชีจะค้างในรายการสูงสุด 7 วันหลังการส่งล่าสุด และขึ้นสถานะออฟไลน์เมื่อขาดอัปเดต 60 วินาที
