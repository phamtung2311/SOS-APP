# Báo Cáo Công Việc: M6 - Kiểm Thử Bảo Mật & Benchmark Mật Mã

- **Thời gian hoàn thành:** 07/11/2026
- **Nhiệm vụ:** Bộ test mô phỏng 4 kịch bản tấn công (nghe lén, can thiệp dữ liệu, phát lại, giả mạo GPS) và đo hiệu năng mật mã (Milestone 6).

## 1. Tóm tắt kết quả
- **Tạo mới `test/security_attack_suite_test.dart`** (13 test): ATK-01 nghe lén (ciphertext/MAC của `EncryptedSosPayload` & `ChatMessage` không chứa tọa độ hay plaintext; bên thứ ba không private key không giải được), ATK-02 bit-flipping (đảo 1 bit ciphertext/MAC/nonce → `SecretBoxAuthenticationError`), ATK-03 replay (`ReplayGuard` từ chối gói tin quá hạn và nonce trùng), ATK-04 giả mạo GPS (`TamperDetector`, `TamperReport.isTrusted=false`, `AppState.isMockGps`).
- **Tạo mới `lib/data/services/replay_guard.dart`**: cơ chế chống phát lại thật sự — `ReplayVerdict` (accepted/expired/duplicateNonce), ngưỡng tuổi mặc định `AppConstants.sosExpiresAfter` (30 phút), tự dọn nonce cũ; `ReplayAttackException`.
- **Tạo mới `test/crypto_benchmark_test.dart`** (2 test): đo 300 vòng lặp cho ECDH X25519, AES-256-GCM encrypt/decrypt (vị trí SOS), SHA-256 mã 6 số, decrypt chat E2EE; in bảng kết quả ra console và assert mỗi thao tác < 10 ms.
- **Kết quả benchmark**: ECDH X25519 **0.80 ms**, AES-GCM encrypt **0.11 ms**, AES-GCM decrypt **0.08 ms**, SHA-256 **0.03 ms**, chat decrypt **0.05 ms** (trung bình) — thấp hơn ngưỡng 10 ms hơn 2 đơn vị.

## 2. Lệnh đã thực thi & Mã thoát (Exit Code)
- `flutter test` — **Exit 0** (86/86 tests PASS: 71 tests cũ + 15 tests mới M6).
- `flutter analyze` — **Exit 0** (No issues found: 0 errors, 0 warnings, 0 infos).
- `git commit` & `git push origin main` — **Exit 0**.

## 3. Trạng thái & Nghiệm thu
- **Trạng thái:** Hoàn thành 100% Milestone 6. Không cần mở máy ảo `Medium_Phone` — toàn bộ kiểm chứng chạy headless qua `flutter test`.
- **Lưu ý kỹ thuật:** `ReplayGuard` là thành phần production mới; đã được unit-test đầy đủ (5 test) nhưng chưa tích hợp vào luồng nhận gói tin SOS thật (Firestore listener) — việc này thuộc milestone tiếp theo.
- **Sẵn sàng tiếp nhận:** Milestone 7 (tích hợp `ReplayGuard` vào Firestore, hoàn thiện luồng đăng nhập Firebase Auth, sinh báo cáo đồ án).
