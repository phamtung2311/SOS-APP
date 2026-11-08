# Báo Cáo Công Việc: Khóa Phòng Chat E2EE Thật (ECDH X25519) & Bảo Mật Firestore

- **Thời gian thực hiện:** 08/11/2026
- **Người thực hiện:** Antigravity AI
- **Mục tiêu:** Nâng cấp khóa phòng chat E2EE thật qua ECDH X25519 với Android Keystore, xóa hoàn toàn plaintext khỏi Firestore doc, loại bỏ fake seeds, và xử lý trạng thái gửi thực tế kèm retry.

---

### 1. Tóm tắt kết quả
- **`CryptoService`:** Thêm `deriveChatKeyForPeer()` và `deriveChatKeyFromB64()` (ECDH X25519 + HKDF-SHA256 sinh AES-256 key), giữ nguyên `deriveRoomKey()`.
- **`ChatMessage`:** Bổ sung enum `MessageStatus` (`sending`, `sent`, `failed`), phương thức serialize `toFirestoreMap()` / `serializeForFirestore()` TUYỆT ĐỐI không chứa field `plaintext` hay dữ liệu media thô.
- **`FamilyChatScreen`:**
  - `_bootstrap()`: Truy vấn `publicKey` của peer từ Firestore `users/{peerUid}` -> ECDH X25519 với private key trong Android Keystore; fallback `deriveRoomKey` nếu thiếu peer key + hiện nhãn cảnh báo "Chưa thiết lập khóa E2EE – chế độ demo".
  - Loại bỏ hoàn toàn `_seedMessages()` giả lập; thêm empty state "Chưa có tin nhắn nào" và "Không kết nối được máy chủ" kèm nút "Thử lại".
  - Quản lý trạng thái gửi thật (`sending`, `sent`, `failed`), icon ⚠️ + nút "Thử gửi lại", chỉ đồng bộ dọn local khi Firestore write thành công.
- **`test/chat_e2ee_x25519_test.dart`:** Tạo bộ test chứng minh 3 tiêu chí: (i) 2 bên khác public key sinh cùng shared key, (ii) key E2EE ≠ key fallback tĩnh, (iii) Firestore map serialize không chứa `plaintext`.

### 2. Lệnh thực thi chính & Mã thoát
- `flutter analyze`: Exit code 0 (No issues found).
- `flutter test`: Exit code 0 (112/112 tests passed 100%, gồm 108 test cũ + 4 test mới).

### 3. Trạng thái & Nghiệm thu
- **Trạng thái:** Thành công 100%. Đáp ứng trọn vẹn toàn bộ tiêu chí bảo mật E2EE và Firestore.
