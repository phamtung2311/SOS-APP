# BÁO CÁO MILESTONE 0 — SỬA LỖI BUILD (M0)

**Ngày:** 06/11/2026
**Phạm vi:** Project `~/dev/sos_safe_family` (Flutter Android)
**Mục tiêu:** Nghiệm thu bước build nền tảng `flutter build apk --debug` thành công, dọn sạch dependency lỗi, sẵn sàng cho Milestone 1.

---

## 1. Nguyên nhân lỗi

- **Lỗi gốc 1:** Package `background_locator_2` (v2.0.6) dùng repository `jcenter()` trong `android/build.gradle.kts`. JCenter đã chính thức ngừng hoạt động → lệnh `flutter build apk --debug` trả về `Could not find method jcenter()`.
- **Lỗi gốc 2 (sau khi gỡ 1):** Package `permission_handler` (v14.1.1) hardcode `compileSdk = 37` trong module Android (`permission_handler_android`), trong khi project hiện tại pin `compileSdk 36` (theo cấu hình Android Studio + Gradle Plugin 9.1.0 chỉ hỗ trợ tối đa SDK 36). Kết quả: lỗi `checkAarMetadata` — "Dependency ':permission_handler_android' requires compile against version 37 or later".
- Máy chủ SDK chỉ có platform đến `android-37.0` (bản preview, chưa chính thức trong repo), nên không thể nâng `compileSdk 37` một cách bền vững.

## 2. Giải pháp đã thực hiện

1. **Gỡ bỏ package lỗi:** `flutter pub remove background_locator_2` (thay thế bằng `geolocator` thuần, xử lý ở M2).
2. **Sửa 2 model có lỗi cú pháp** (bắt gặp khi chạy `flutter analyze` sau khi gỡ package):
   - `lib/data/models/user.dart` và `lib/data/models/family_circle.dart`:
     - `Timestamp` trong cloud_firestore 7.x không phải `const` constructor → bỏ `const`.
     - `DocumentSnapshot` giờ là generic type (`DocumentSnapshot<Map<String, dynamic>>`), khai báo raw type làm `data()` trả `Object?` → dùng đúng generic, dùng `whereType<Map<String, dynamic>>()` khi parse danh sách.
3. **Hạ version `permission_handler`:** `flutter pub add permission_handler:12.0.3` (module Android tương ứng là `permission_handler_android` 12.0.3 → `compileSdk 33`, tương thích hoàn toàn với `compileSdk 36`).

## 3. Kết quả nghiệm thu

- `flutter analyze`: **No issues found**
- `flutter build apk --debug`: **BUILD SUCCESSFUL** (lần build cuối cùng ~203s)
- File APK đầu ra:

  ```
  /home/tung/dev/sos_safe_family/build/app/outputs/flutter-apk/app-debug.apk
  (162 MB)
  ```

- Đã tạo symlink `~/Android/Sdk/platforms/android-37 -> android-37.0` để xử lý cảnh báo còn sót (không bắt buộc nhưng giúp build sạch hơn).

## 4. Ghi chú / việc tiếp theo

- Build hiện có WARNING về "Built-in Kotlin" cho các plugin `cryptography_flutter`, `firebase_auth`, `firebase_core`, `firebase_storage` — chưa gây lỗi, nhưng nên theo dõi khi upgrade Flutter về sau.
- Milestone 1 (Auth + Firestore + vòng tròn gia đình) sẵn sàng bắt đầu.
