# BÁO CÁO — M2/M3: GEOFENCE (HAVERSINE) & LUỒNG SOS KHẨN CẤP

**Ngày:** 06/11/2026 | **Dự án:** `sos_safe_family` | **Nhánh:** `main` | **Repo:** https://github.com/phamtung2311/SOS-APP.git

## 1. Tóm tắt kết quả

**File MỚI (6):**
- `lib/data/models/geofence.dart` — model `Geofence` (id, name, center, radius, isEnabled, isInside) + `copyWith`/`toJson`/`fromJson`
- `lib/data/services/geofence_service.dart` — Haversine (R=6 371 000 m), `checkGeofenceStatus`, `evaluateTransitions` (ENTER/EXIT), `updateFenceStatuses`, `seedGeofences`
- `lib/data/models/sos_event.dart` — model `SosEvent` + enum `SosStatus` (ACTIVE/RESOLVED), `resolve()`
- `lib/data/services/sos_service.dart` — `SosService.encryptEvent()` mã hóa AES-256-GCM toàn bộ payload SOS
- `lib/core/app_state.dart` — state chung: vị trí, geofence, SOS, nhật ký kiểm toán (`AppScope`)
- `lib/presentation/screens/sos_countdown_screen.dart` — modal đếm ngược 3-2-1 + nút HỦY

**File SỬA (2):** `lib/main.dart` (CircleLayer geofence, BottomSheet danh sách vùng, SOS countdown, banner đỏ khẩn cấp, audit log), `test/widget_test.dart` (6 test).

**Test MỚI (44):** `test/geofence_test.dart` (23) + `test/sos_test.dart` (17).

## 2. Lệnh đã thực thi & Nghiệm thu

| Lệnh | Exit | Kết quả |
|---|---|---|
| `flutter analyze` | 0 | *No issues found!* (0 Error/Warning/Info) ✅ |
| `flutter test` | 0 | *59/59 All tests passed* (15 cũ + 44 mới) ✅ |
| `flutter build apk --debug` | 0 | `✓ Built build/app/outputs/flutter-apk/app-debug.apk` ✅ |
| `git add . && git commit && git push origin main` | 0 | ✅ |

**Geofence:** độ chính xác Haversine với test-vector thực (Hà Nội→TP.HCM 1 137 867 m; Hồ Hoàn Kiếm→BV 103 Trần Hữu Dực 7 317 m; Hồng Kông→Ma Cao 65 751 m); vào/ngoài bán kính; chuỗi ENTER→EXIT→ENTER; chống spam khi đứng yên.
**SOS:** đóng gói payload 8 trường; vòng đời ACTIVE→RESOLVED; mã hóa AES-256-GCM không rò rỉ toạ độ plaintext; nonce ngẫu nhiên; chống tamper/sai khoá.
**Tính năng:** SOS giữ 2s → đếm ngược 3-2-1 (HỦY được) → banner đỏ "TRẠNG THÁI KHẨN CẤP ĐANG BẬT" + nút "TÔI ĐÃ AN TOÀN" → audit log `[HH:mm] Bạn đã kích hoạt cảnh báo SOS (Đã mã hóa E2EE)`. Geofence vẽ bằng `CircleLayer` (viền xanh/cam, nền `alpha 0.2`), BottomSheet 2 vùng mẫu (Nhà riêng 100m, Cơ quan/Trường học 200m).

## 3. Ghi chú kỹ thuật

- `checkGeofenceStatus` dùng `distance <= radius` (biên tính là **trong** vùng).
- `evaluateTransitions` so sánh `fence.isInside` (trước) với trạng thái hiện tại → chỉ phát sự kiện khi trạng thái **thực sự đổi**.
- SOS luôn kích hoạt được kể cả khi chưa có GPS (dùng toạ độ cuối cùng, đánh dấu `isMocked = true`).
- Timer đếm ngược huỷ trước khi đóng dialog khi bấm HỦY — tránh kích hoạt SOS ngoài ý muốn.
- Mức pin hiện là giá trị mô phỏng (87%); điểm tích hợp `battery_plus` để để sau.
