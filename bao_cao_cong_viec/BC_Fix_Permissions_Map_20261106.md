# BÁO CÁO FIX LỖI TẢI BẢN ĐỒ & CẤP QUYỀN (MAP FIX)

**Ngày:** 06/11/2026
**Phạm vi:** Project `~/dev/sos_safe_family` (Android Native & Flutter)

## 1. Nguyên nhân lỗi
- `AndroidManifest.xml` thiếu quyền `INTERNET` và `ACCESS_FINE_LOCATION`, khiến Android chặn tải tile bản đồ từ mạng.
- Máy chủ `tile.openstreetmap.org` bị lỗi phân giải DNS/chặn truy cập trên mạng di động và mạng Wi-Fi tại Việt Nam.

## 2. Giải pháp đã thực hiện
1. **Bổ sung quyền trong AndroidManifest.xml:**
   - `android.permission.INTERNET`
   - `android.permission.ACCESS_FINE_LOCATION`
   - `android.permission.ACCESS_COARSE_LOCATION`
   - `android.permission.ACCESS_NETWORK_STATE`
2. **Chuyển đổi Tile Server sang Google Maps Raster Tiles:**
   - URL: `https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}`
   - Ưu điểm: Tốc độ tải cực nhanh, miễn phí, không cần API key, hiển thị bản đồ tiếng Việt sắc nét (Hà Nội, Sông Hồng, Hồ Tây...).

## 3. Kết quả nghiệm thu
- Rebuild APK thành công trong 8.8s (`flutter build apk --debug`).
- Cài đặt và cập nhật trực tiếp lên thiết bị thật **Xiaomi Redmi Note 11 (220333QAG)**.
- Bản đồ hiển thị Full HD mượt mà, đầy đủ địa danh, sông ngòi, đường phố và marker thành viên gia đình.
