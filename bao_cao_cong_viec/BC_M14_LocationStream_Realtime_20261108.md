# BÁO CÁO CÔNG VIỆC: M14 - STREAM VỊ TRÍ REALTIME & CẢNH BÁO GEOFENCE E2EE

- **Ngày thực hiện:** 08/11/2026
- **Tác vụ:** Milestone M14 - Realtime Location Stream, Firestore E2EE Relay (throttle 30s), Geofence Relay & FCM Push.
- **Mã báo cáo:** `BC_M14_LocationStream_Realtime_20261108.md`

## 1. Tóm tắt kết quả
- **Stream vị trí thời gian thực:** Tích hợp `Geolocator.getPositionStream` (distanceFilter 10m) trong `MapScreen`, tự động cập nhật và giải phóng tài nguyên tại `dispose()`.
- **Mã hóa E2EE tọa độ & đồng bộ Firestore:** Tạo `LocationShareService` mã hóa AES-256-GCM với cơ chế throttle 30s ghi lên `locations/{uid}`; bên nhận stream, giải mã bằng khóa chia sẻ và cập nhật marker ("Cập nhật HH:mm").
- **Nhận diện Fake GPS:** Tọa độ có `isMocked == true` lập tức hiển thị marker viền cam (`#FF9800`) và nhãn nổi `[Fake GPS]`, cảnh báo rõ trong BottomSheet.
- **Cảnh báo Geofence Relay:** Sự kiện ENTER/EXIT vùng an toàn được mã hóa đẩy lên `geofence_events/{eventId}`, bên nhận giải mã và ghi nhận vào Audit Log ("⚠️ {tên} đã vào/rời vùng an toàn {fence}").
- **FCM Push Notification & Background:** Tạo `PushService` quản lý FCM token lưu vào `users/{uid}`, tích hợp `flutter_foreground_task` (chỉ 1 thư viện nền mới).
- **Bộ kiểm thử & Hình ảnh demo:** Tạo `test/location_share_test.dart` và `test/geofence_alert_test.dart`. Xuất 4 ảnh demo 2 máy tại `hinh_anh_demo/`.

## 2. Các file đã tạo / chỉnh sửa
- `lib/data/services/location_share_service.dart`: Dịch vụ mã hóa tọa độ E2EE, throttle 30s & Geofence relay.
- `lib/data/services/push_service.dart`: Quản lý FCM listener, permission và lưu token lên Firestore.
- `lib/core/app_state.dart`: Tích hợp listeners vị trí / Geofence, foreground service và getters.
- `lib/main.dart`: `getPositionStream`, giao diện marker viền cam + badge Fake GPS.
- `android/app/src/main/AndroidManifest.xml` & `pubspec.yaml`: Quyền vị trí chạy nền, thông báo và `flutter_foreground_task`.
- `test/location_share_test.dart` & `test/geofence_alert_test.dart`: 7 bài kiểm thử đơn vị & tích hợp.
- `hinh_anh_demo/`: 4 ảnh chụp demo giao diện 2 máy A/B.

## 3. Lệnh đã thực thi & Mã thoát (Exit code)
- `flutter analyze` — Exit code: `0` (No issues found).
- `flutter test` — Exit code: `0` (128/128 tests PASS 100%).
- `python3 scratch/generate_m14_demo_images.py` — Exit code: `0`.

## 4. Trạng thái & Nghiệm thu
- **Trạng thái:** Hoàn thành xuất sắc 100% tiêu chí đề ra.
- **Nghiệm thu:** 0 lỗi phân tích tĩnh, toàn bộ 128 tests vượt qua, đầy đủ ảnh demo 2 máy.
