# Báo Cáo Công Việc: M5 - Emergency Bypass, Sinh Trắc Học & Hardening

- **Thời gian hoàn thành:** 07/11/2026 (Phiên tối 06/11)
- **Nhiệm vụ:** Kiến trúc Emergency Bypass (Zero Barrier SOS/Map), Scoped Gate sinh trắc học, native FLAG_SECURE, kiểm tra root/mock GPS và chia sẻ hành trình SHA-256 (Sprint 5A).

## 1. Tóm tắt kết quả
- **Emergency Bypass Architecture:** Mở app vào thẳng Map & nút SOS không rào cản (Zero Barrier). Sinh trắc học (`local_auth`) chỉ bảo vệ vùng nhạy cảm (Tab Vòng tròn, Nhật ký, Cá nhân, Chat E2EE). Quản lý phiên (`isUnlockedThisSession`) tự khoá khi background timeout.
- **Native Android Hardening:** `MainActivity.kt` kế thừa `FlutterFragmentActivity`, `MethodChannel("vn.atbm.sos/security")` điều khiển `FLAG_SECURE` chống chụp/quay màn hình và kiểm tra root (`/system/bin/su`, test-keys).
- **Chia sẻ hành trình (Sprint 5A):** `TripShareService` sinh mã 6 số CSPRNG, băm SHA-256 trước khi lưu/truyền tin, dialog đếm ngược TTL 60 phút trên bản đồ.
- **UI & Quản lý trạng thái:** Cập nhật `AppState` liên kết `SecurityScreen` (switch sinh trắc học, switch FLAG_SECURE, thẻ TamperReport toàn vẹn thiết bị).
- **Files tạo mới/sửa:** `MainActivity.kt`, `AndroidManifest.xml`, `build.gradle.kts`, `styles.xml`, `app_state.dart`, `biometric_service.dart`, `tamper_detector.dart`, `native_security_service.dart`, `trip_share_service.dart`, `main.dart`, `emergency_bypass_test.dart`, `trip_share_test.dart`.

## 2. Lệnh đã thực thi & Mã thoát (Exit Code)
- `flutter analyze` — **Exit 0** (0 errors, 0 warnings).
- `flutter test` — **Exit 0** (Đỗ toàn bộ 71/71 tests: 59 tests cũ + 12 tests mới M5).
- `flutter build apk --debug` — **Exit 0** (Sinh thành công `app-debug.apk` trong 67s).
- `git commit` & `git push origin main` — **Exit 0** (Commit `fea99ed` đẩy lên GitHub).

## 3. Trạng thái & Nghiệm thu
- **Trạng thái:** Hoàn thành 100% Milestone 5 & Sprint 5A. Mã nguồn sạch, không lỗi phân tích.
- **Sẵn sàng tiếp nhận:** Milestone 6 (Đánh giá bảo mật, thử nghiệm tấn công & báo cáo đồ án).
