# Báo Cáo Công Việc: M7 - Tích Hợp ReplayGuard & Báo Cáo Đồ Án ATBM

- **Thời gian hoàn thành:** 07/11/2026
- **Nhiệm vụ:** Tích hợp `ReplayGuard` vào luồng nhận SOS thật và soạn báo cáo đồ án tốt nghiệp theo Khung mục 6.1 (Milestone 7).

## 1. Tóm tắt kết quả

**Nhiệm vụ A — Tích hợp ReplayGuard:**
- `lib/data/services/sos_service.dart`: thêm `ReplayGuard` vào `SosService` + phương thức `receiveSos()` — kiểm tra nonce trùng **trước** khi giải mã, giải mã AES-256-GCM (tự kiểm tra MAC), kiểm tra tuổi gói tin (TTL 30 phút) **sau** khi giải mã; ném `ReplayAttackException` khi bị từ chối.
- `lib/core/app_state.dart`: thêm `receiveIncomingSos()` — bắt `ReplayAttackException`/`SecretBoxAuthenticationError`, ghi cảnh báo tấn công vào `auditLogs` và **không** kích hoạt cảnh báo SOS.
- `test/security_attack_suite_test.dart`: thêm nhóm **ATK-03b** (5 test) — gói tin hợp lệ được chấp nhận, replay cùng nonce bị từ chối, gói tin quá hạn bị từ chối, `AppState` kích hoạt cảnh báo + ghi log hợp lệ, replay bị từ chối + ghi log "TẤN CÔNG".

**Nhiệm vụ B — Báo cáo đồ án:**
- Tạo `/home/tung/Màn hình nền/ATBM/Bao_cao_Do_an_ATBM_SOS_An_toan_Gia_dinh.md` (488 dòng) theo đúng Khung mục 6.1: Mở đầu → Chương 1 (X25519/ECDH, HKDF-SHA256, AES-256-GCM, SHA-256/CSPRNG, 5 nguy cơ tấn công) → Chương 2 (kiến trúc 3 tầng, Zero Barrier/Scoped Gate, STRIDE, giao thức trao đổi khóa) → Chương 3 (bảng màn hình, benchmark M6, kết quả 4 kịch bản tấn công, 91/91 test) → Chương 4 (kết luận, bài học, hướng phát triển) → Tài liệu tham khảo (14 mục) + Phụ lục 9 cơ chế bảo mật.
- Mọi số liệu trong báo cáo lấy từ kết quả chạy thực tế, không ước lượng.

## 2. Lệnh đã thực thi & Mã thoát (Exit Code)
- `flutter test` — **Exit 0** (91/91 tests PASS: 86 của M6 + 5 test M7).
- `flutter analyze` — **Exit 0** (No issues found: 0 errors, 0 warnings, 0 infos).
- `git commit` & `git push origin main` — **Exit 0**.

## 3. Trạng thái & Nghiệm thu
- **Trạng thái:** Hoàn thành 100% Milestone 7. Luồng nhận SOS đã có cơ chế chống phát lại thật sự, không còn là mô phỏng trong test.
- **Lưu ý:** `ReplayGuard` mới được nối vào `SosService`/`AppState`; chưa gọi từ Firestore listener thật — hạng mục ưu tiên cao của M8.
- **Sẵn sàng tiếp nhận:** M8 (tích hợp Firestore listener + chữ ký Ed25519 + demo hai chiều trên thiết bị thật + ảnh chụp E2EE).
