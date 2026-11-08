# DANH MỤC ĐỐI CHIẾU: TÍNH NĂNG THỰC TẾ VS MÔ PHỎNG (DEMO / MOCK)
**Đồ án:** Ứng dụng Báo động SOS và Giám sát An toàn Gia đình (SafeFamily SOS)  
**Tài liệu đối chiếu:** Đề cương chi tiết §3, §4, §5 (`De_cuong_SOS_An_toan_Gia_dinh.md`)  
**Mục đích:** Phục vụ bảo vệ đồ án và phần *"Hạn chế & Hướng phát triển"* trong báo cáo chính thức.

---

## 1. Bảng đối chiếu tổng hợp theo các mục đề cương

| STT | Tính năng theo đề cương | Đã triển khai thực tế (Production/Real) | Vẫn là mô phỏng / Hạn chế (Demo / Mock) | Ghi chú kỹ thuật |
|---|---|---|---|---|
| **1** | **Mã hóa E2EE (X25519 & AES-GCM)** (§3.1, §4.2, §5.2) | **Thực tế 100%**: Sinh cặp khóa X25519; lưu private key vào Android Keystore; trao đổi public key qua Firestore; tính shared secret qua ECDH + HKDF-SHA256 (32 byte); mã hóa AES-256-GCM không lộ plaintext lên server. | Chưa tích hợp hạ tầng chứng chỉ số công cộng (PKI / X.509 CA); xác thực khóa ngoài băng tần bằng Security Fingerprint SHA-256 (8 cụm hex). | `CryptoService`, `AuthService`, `FamilyChatScreen` |
| **2** | **Chống tấn công phát lại (Replay Guard)** (§3.1) | **Thực tế 100%**: Nonce 12-byte ngẫu nhiên cho mỗi payload; kiểm tra timestamp với cửa sổ thời gian trôi (time window 60s); bộ nhớ đệm chống trùng nonce. | Bộ nhớ đệm nonce lưu trong RAM phiên chạy, chưa đồng bộ qua cơ sở dữ liệu phân tán Redis/Cloud. | `ReplayGuard` |
| **3** | **SOS Relay & Khẩn cấp** (§3.2, §5.3) | **Thực tế 100%**: Nhấn giữ 3s chống chạm nhầm; mã hóa vị trí đẩy lên `sos_events/{sosId}`; bên nhận stream Firestore nhận banner khẩn cấp <5s; giải quyết SOS hai chiều (`resolved`). | **Chưa có bản ghi âm SOS**: Đề cương nêu có bản ghi âm ngắn mã hóa tải lên blob; hiện tại chỉ truyền dữ liệu tọa độ, pin và trạng thái khẩn cấp (chưa bật microphone native). | `AppState`, `SosService`, `SosEmergencyBanner` |
| **4** | **Bảo vệ thiết bị & Toàn vẹn** (§3.4) | **Thực tế 100%**: Cờ `FLAG_SECURE` chặn chụp/quay màn hình; tự động khóa sinh trắc học khi chạy nền (`BiometricService`); phát hiện Fake GPS qua `Position.isMocked`. | Phát hiện Root hiện kiểm tra cơ bản qua binary path (`/system/bin/su`, test-keys); chưa tích hợp Play Integrity API / SafetyNet từ Google Play. | `TamperDetector`, `BiometricService` |
| **5** | **Bản đồ & Vùng an toàn (Geofence)** (§3.2, §4.2) | **Thực tế 100%**: Tính khoảng cách mặt cầu bằng Haversine; phát hiện ENTER/EXIT; mã hóa sự kiện đẩy lên `geofence_events` và ghi Audit Log; stream vị trí thời gian thực `getPositionStream` (throttle 30s). | Nền tảng bản đồ dùng OpenStreetMap / Google Maps tiles qua FlutterMap; chưa dùng Google Maps SDK native bản trả phí. | `GeofenceService`, `LocationShareService`, `MapScreen` |
| **6** | **Cơ sở dữ liệu cục bộ** (§3.4, §4.2) | **Thực tế một phần**: Lưu trữ khóa bí mật, profile và token bảo mật qua `flutter_secure_storage` (Android Keystore / EncryptedSharedPreferences). | **SQLCipher**: Thư viện có trong dependencies nhưng chưa tạo đầy đủ schema bảng SQLite cục bộ cho offline caching hoàn chỉnh; hiện dựa vào Firestore offline cache & RAM. | `SecureStorageService` |
| **7** | **Bảo vệ kênh truyền & Mạng** (§3.4) | **Thực tế**: Toàn bộ kết nối ra ngoài dùng giao thức HTTPS/TLS của Firebase SDK và Google APIs. | **Certificate Pinning**: Chưa cấu hình HPKP / Public Key Pinning trong `network_security_config.xml` cho domain Firebase; Rate-limiting OTP phụ thuộc quota mặc định của Firebase Auth. | `AndroidManifest.xml` |
| **8** | **Làm rối mã nguồn (R8/ProGuard)** (§3.4, §4.2) | **Thực tế trong cấu hình Release**: Đã cấu hình quy tắc ProGuard trong `android/app/proguard-rules.pro`. | Bản build kiểm thử hằng ngày là `debug APK` (`flutter build apk --debug`); R8 chỉ chạy khi kích hoạt `flutter build apk --release`. | `build.gradle`, `proguard-rules.pro` |
| **9** | **Nhật ký kiểm toán (Audit Log)** (§3.3, §5.1) | **Thực tế 100%**: Ghi nhận toàn bộ thao tác bảo mật (sinh khóa, mã hóa tin nhắn, SOS, vào/ra vùng, phát hiện Fake GPS, khóa sinh trắc học) vào danh sách kiểm toán có timestamp. | Danh sách lưu cục bộ trên thiết bị và đồng bộ Firestore một phần; chưa triển khai blockchain/append-only log server chống chối bỏ cấp doanh nghiệp. | `AppState.addAuditLog`, `AuditLogScreen` |
| **10** | **Đồng bộ lời mời & Thành viên** (§3.3, §5.2) | **Thực tế 100%**: Mã mời 6 chữ số sinh ngẫu nhiên tra cứu Firestore; xác thực 2 chiều (chấp thuận/từ chối); loại bỏ toàn bộ dữ liệu mẫu giả định. | Chưa có cơ chế quét mã QR cho lời mời (hiện dùng mã OTP/Pairing code 6 chữ số). | `CircleScreen`, `AppState` |

---

## 2. Điểm cần lưu ý khi trả lời Hội đồng bảo vệ đồ án
1. **Khẳng định mạnh mẽ:** Toàn bộ luồng mã hóa E2EE (X25519 + AES-256-GCM), bảo vệ dữ liệu nhạy cảm (chat, vị trí, sự kiện SOS) là **dữ liệu thật, mã hóa thật**; trên Firestore chỉ nhìn thấy chuỗi ciphertext Base64, không một ai (kể cả admin máy chủ) đọc được nội dung gốc.
2. **Thành thật về giới hạn:** Bản ghi âm SOS đa phương tiện và SQLCipher cục bộ là 2 điểm chưa hoàn thiện 100% theo bản thảo ban đầu và đã được đưa vào mục *"Hướng phát triển sau đồ án"* (Chương 4).
