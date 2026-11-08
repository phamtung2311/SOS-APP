# Báo Cáo Công Việc: Truyền Phát Cảnh Báo Khẩn Cấp SOS Realtime Qua Firestore (2 Thiết Bị)

- **Thời gian thực hiện:** 08/11/2026
- **Người thực hiện:** Antigravity AI
- **Mục tiêu:** Hiện thực hóa cơ chế phát & nhận tín hiệu SOS E2EE thời gian thực giữa 2 thiết bị qua Cloud Firestore (`sos_events`), tự động ẩn banner khi an toàn, chống giả mạo MAC/Replay, và chụp ảnh nghiệm thu UI 2 máy.

---

### 1. Tóm tắt kết quả
- **`AppState` (`lib/core/app_state.dart`):**
  - `activateSos()`: Đóng gói và mã hóa E2EE payload, upsert lên Firestore `sos_events/{sosId}` (`encryptedEvent`, `encryptedLocation`, `senderUid`, `senderName`, `status: 'active'`, `createdAt`, `nonce`, `sessionKeyId`). Khóa phiên E2EE thật nếu có peer key, fallback demo key nếu chưa. Ghi Audit Log nếu có lỗi.
  - `initSosListener()`: Stream listener `sos_events` lọc bỏ sự kiện của chính mình (`senderUid != currentUid`), tiếp nhận sự kiện `status == 'active'` qua `receiveIncomingSos` (tự động kiểm tra Replay Guard và xác thực MAC).
  - Tự động hủy/ẩn banner nhận khi sự kiện chuyển sang `status == 'resolved'` (`clearIncomingSos`).
  - `resolveSos()`: Khi bấm "TÔI ĐÃ AN TOÀN", update doc `sos_events/{sosId}` với `status: 'resolved'` và `resolvedAt`. Báo lỗi nếu write thất bại, không tự nhận an toàn khi chưa gửi được.
- **`MainScreen` / `SosEmergencyBanner` (`lib/main.dart`):**
  - Hiển thị banner khẩn cấp phân tách rõ 2 vai trò: Phía người gửi ("TRẠNG THÁI KHẨN CẤP ĐANG BẬT" + chỉ hiện "Đã gửi tới gia đình" sau khi Firestore thành công + nút "TÔI ĐÃ AN TOÀN"); Phía người nhận ("⚠️ {TÊN} GỬI SOS" + tọa độ/pin + nút "Mở bản đồ" và "Tôi đã hỗ trợ").
- **Kiểm thử & Demo (`test/sos_relay_test.dart` & `hinh_anh_demo/`):**
  - Test 1-4: Vòng đời active -> resolved giữa 2 máy; gói tin sai MAC bị từ chối & ghi Audit Log; receiver lọc sự kiện của chính mình; kiểm thử UI banner & buttons.
  - Đã xuất 4 ảnh màn hình mô phỏng 2 thiết bị vào `hinh_anh_demo/` (ở cả dev và ATBM).

### 2. Lệnh thực thi chính & Mã thoát
- `flutter analyze`: Exit code 0 (No issues found).
- `flutter test`: Exit code 0 (116/116 tests passed 100%, gồm 112 test cũ + 4 test mới).

### 3. Trạng thái & Nghiệm thu
- **Trạng thái:** Hoàn thành xuất sắc 100%. Không đổi các file ngoài phạm vi (`crypto_service.dart`, `replay_guard.dart`).
