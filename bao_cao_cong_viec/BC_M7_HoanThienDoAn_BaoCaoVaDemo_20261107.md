# Báo Cáo Công Việc: M7 - Hoàn Thiện Đồ Án, Báo Cáo & Kịch Bản Demo Bảo Vệ

- **Thời gian hoàn thành:** 07/11/2026
- **Nhiệm vụ:** Tích hợp `ReplayGuard` vào production code, biên soạn báo cáo đồ án, slide & kịch bản demo bảo vệ (Milestone 7).

## 1. Tóm tắt kết quả

**Tích hợp ReplayGuard (production code):**
- `lib/data/models/encrypted_sos_payload.dart` (**tạo mới**): tách `EncryptedSosPayload` ra model riêng, bổ sung `nonceBase64` (trích 12 byte đầu transport) + `sentAt` + `fromWireJson()`.
- `lib/data/services/replay_guard.dart` (**viết lại**): thêm API `evaluate(EncryptedSosPayload, {now})` theo đúng spec; `ReplayAttackException` có thêm `.reason`; thêm `trackedNonceCount`.
- `lib/data/services/sos_service.dart`: thêm `handleIncomingSos({encryptedPayload, sharedKey, receiveTime})` — thứ tự kiểm tra **nonce trùng → giải mã AES-GCM → timestamp đã xác thực**; gói tin bị từ chối **không tốn công giải mã**.
- `lib/core/app_state.dart`: `receiveIncomingSos()` bắt `ReplayAttackException`/`SecretBoxAuthenticationError`, ghi cảnh báo tấn công vào `auditLogs`, không kích hoạt cảnh báo.
- Test mới: 5 test trong `test/sos_test.dart` (gói hợp lệ, duplicateNonce, expired, MAC sai, Nonce Registry) + 5 test ATK-03b trong `test/security_attack_suite_test.dart`.

**Tài liệu (tại `/home/tung/Màn hình nền/ATBM/`):**
- `Bao_cao_Do_an_ATBM_SOS_An_toan_Gia_dinh.md` — **báo cáo đồ án 4 chương + Mở đầu + TLTK (14 mục) + Phụ lục 9 cơ chế**, bám sát Khung mục 6.1; có số liệu thực nghiệm thật, không bịa.
- `Slide_Thuyet_Trinh_Bao_Ve_ATBM.md` — **17 slide** + phụ lục gợi ý trả lời câu hỏi hội đồng.
- `Kich_ban_Demo_Bao_ve_Do_an.md` — **kịch bản demo 3 phút / 4 cảnh** + bảng xử lý sự cố backup.

## 2. Lệnh đã thực thi & Mã thoát (Exit Code)
- `flutter analyze` — **Exit 0** (No issues found: 0 errors, 0 warnings, 0 infos).
- `flutter test` — **Exit 0** (**96/96 tests PASS**).
- `git commit` & `git push origin main` — **Exit 0**.

## 3. Trạng thái & Nghiệm thu
- **Trạng thái:** Hoàn thành 100% Milestone 7 — code production đã có chống phát lại thật, hồ sơ bảo vệ đồ án hoàn chỉnh (báo cáo + slide + kịch bản demo).
- **Lưu ý:** `handleIncomingSos()` chưa được gọi từ Firestore listener thật — hạng mục ưu tiên cao của M8. Bản ghi M7 cũ (`BC_M7_BaoCaoDoAn_TichHop_20261107.md`) được giữ lại làm dấu vết milestone.
- **Sẵn sàng tiếp nhận:** M8 (Firestore listener thật, chữ ký Ed25519, demo 2 thiết bị + ảnh E2EE, Mesh BLE).
