# BC_M19_MemberUidNormalize_20261109
- Tóm tắt: sửa member.id về Firebase UID thật, chặn UID giả từ email, query invitation 1 field + match client-side, và đồng bộ khóa SOS/location theo peer UID.
- File sửa: lib/core/app_state.dart, lib/presentation/screens/family_chat_screen.dart, test/member_uid_normalize_test.dart, test/sos_key_symmetric_test.dart.
- Lệnh và exit code: Analyzing sos_safe_family...                                    
No issues found! (ran in 3.6s) -> 0; 00:00 +0: loading /home/tung/dev/sos_safe_family/test/crypto_service_test.dart
00:00 +0: /home/tung/dev/sos_safe_family/test/crypto_service_test.dart: CryptoService offline security ECDH key agreement derives the same AES-256 key
00:00 +1: /home/tung/dev/sos_safe_family/test/crypto_service_test.dart: CryptoService offline security round-trip encryption and decryption preserves payload data
00:00 +2: /home/tung/dev/sos_safe_family/test/crypto_service_test.dart: CryptoService offline security tampered payload or wrong key throws an exception
00:00 +3: /home/tung/dev/sos_safe_family/test/crypto_service_test.dart: CryptoService offline security nonce randomness ensures unique ciphertext for each encryption
00:00 +4: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption text message round-trip returns the original plaintext
00:00 +5: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption ciphertext does not leak the plaintext
00:00 +6: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption nonce is 12 bytes and mac is 16 bytes
00:00 +7: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption same plaintext encrypts to different ciphertext each time
00:00 +8: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Geofence model copyWith chỉ thay đổi trường được chỉ định
00:00 +9: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption media bytes round-trip preserves binary data
00:00 +10: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption media bytes round-trip preserves binary data
00:00 +11: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption media bytes round-trip preserves binary data
00:00 +12: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption media bytes round-trip preserves binary data
00:00 +13: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption media bytes round-trip preserves binary data
00:00 +14: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption media bytes round-trip preserves binary data
00:00 +15: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption media bytes round-trip preserves binary data
00:00 +16: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Haversine — độ chính xác công thức đối xứng: khoảng cách A→B bằng B→A
00:00 +17: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption tampered ciphertext fails authentication
00:00 +18: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption tampered ciphertext fails authentication
00:00 +19: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption tampered ciphertext fails authentication
00:00 +20: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption tampered ciphertext fails authentication
00:00 +21: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Kiểm tra trạng thái trong / ngoài vùng điểm cách ~100.3m về phía đông nằm NGOÀI vùng 100m
00:00 +22: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption wrong key cannot decrypt the message
00:00 +23: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: E2EE chat encryption wrong key cannot decrypt the message
00:00 +24: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Kiểm tra trạng thái trong / ngoài vùng biên: khoảng cách đúng bằng bán kính vẫn được coi là bên trong
00:00 +25: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: ChatMessage model isMine is true only for the local sender
00:00 +26: /home/tung/dev/sos_safe_family/test/chat_e2ee_test.dart: ChatMessage model isMine is true only for the local sender
00:00 +27: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Chuyển trạng thái ENTER / EXIT từ ngoài vào trong phát sinh sự kiện ENTER
00:00 +28: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Chuyển trạng thái ENTER / EXIT từ ngoài vào trong phát sinh sự kiện ENTER
00:00 +29: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Chuyển trạng thái ENTER / EXIT từ trong ra ngoài phát sinh sự kiện EXIT
00:00 +30: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Chuyển trạng thái ENTER / EXIT đứng yên trong vùng KHÔNG phát sinh sự kiện (chống spam)
00:00 +31: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Chuyển trạng thái ENTER / EXIT đứng yên ngoài vùng KHÔNG phát sinh sự kiện
00:00 +32: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Chuyển trạng thái ENTER / EXIT chuỗi ENTER → EXIT → ENTER được phát hiện đầy đủ
00:00 +33: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Chuyển trạng thái ENTER / EXIT evaluateGeofenceUpdate trả về cả sự kiện lẫn vùng đã cập nhật
00:00 +34: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Chuyển trạng thái ENTER / EXIT nhiều vùng: chỉ vùng bị ảnh hưởng mới phát sự kiện
00:00 +35: /home/tung/dev/sos_safe_family/test/geofence_test.dart: Seed geofences có 2 vùng mặc định với bán kính 100m và 200m
00:00 +36: /home/tung/dev/sos_safe_family/test/sos_test.dart: SosEvent model — đóng gói payload toJson chứa đủ 8 trường bắt buộc
00:00 +37: /home/tung/dev/sos_safe_family/test/sos_test.dart: SosEvent model — đóng gói payload status dùng tên wire đúng quy ước
00:00 +38: /home/tung/dev/sos_safe_family/test/sos_test.dart: SosEvent model — đóng gói payload toJson / fromJson round-trip giữ nguyên dữ liệu
00:00 +39: /home/tung/dev/sos_safe_family/test/sos_test.dart: SosEvent model — đóng gói payload fromJson đọc được status lowercase và giá trị lạ
00:00 +40: /home/tung/dev/sos_safe_family/test/sos_test.dart: SosEvent model — đóng gói payload copyWith không đổi các trường không chỉ định
00:00 +41: /home/tung/dev/sos_safe_family/test/sos_test.dart: Vòng đời trạng thái ACTIVE → RESOLVED sự kiện mới khởi tạo ở trạng thái ACTIVE
00:00 +42: /home/tung/dev/sos_safe_family/test/sos_test.dart: Vòng đời trạng thái ACTIVE → RESOLVED resolve() chuyển ACTIVE → RESOLVED và ghi thời điểm
00:00 +43: /home/tung/dev/sos_safe_family/test/sos_test.dart: Vòng đời trạng thái ACTIVE → RESOLVED resolve() không thay đổi bản gốc (immutability)
00:00 +44: /home/tung/dev/sos_safe_family/test/sos_test.dart: Vòng đời trạng thái ACTIVE → RESOLVED toJson của sự kiện đã resolve chứa resolvedAt
00:00 +45: /home/tung/dev/sos_safe_family/test/sos_test.dart: Vòng đời trạng thái ACTIVE → RESOLVED fromJson khôi phục được sự kiện đã resolve
00:00 +46: /home/tung/dev/sos_safe_family/test/sos_test.dart: Mã hóa payload SOS bằng AES-256-GCM payload mã hóa không chứa toạ độ gốc dạng plaintext
00:00 +47: /home/tung/dev/sos_safe_family/test/sos_test.dart: Mã hóa payload SOS bằng AES-256-GCM giải mã lại được đúng toạ độ gốc bằng đúng khoá
00:00 +48: /home/tung/dev/sos_safe_family/test/sos_test.dart: Mã hóa payload SOS bằng AES-256-GCM giải mã được toàn bộ sự kiện từ encryptedEvent
00:00 +49: /home/tung/dev/sos_safe_family/test/sos_test.dart: Mã hóa payload SOS bằng AES-256-GCM nonce ngẫu nhiên: hai lần mã hóa cho ciphertext khác nhau
00:00 +50: /home/tung/dev/sos_safe_family/test/sos_test.dart: Mã hóa payload SOS bằng AES-256-GCM khoá sai không giải mã được payload SOS
00:00 +51: /home/tung/dev/sos_safe_family/test/sos_test.dart: Mã hóa payload SOS bằng AES-256-GCM payload tampered bị từ chối bởi MAC
00:00 +52: /home/tung/dev/sos_safe_family/test/sos_test.dart: Mã hóa payload SOS bằng AES-256-GCM toWireJson không rò rỉ toạ độ gốc
00:00 +53: /home/tung/dev/sos_safe_family/test/sos_test.dart: Tích hợp ReplayGuard vào luồng nhận SOS (handleIncomingSos) gói SOS hợp lệ được chấp nhận và giải mã đúng toạ độ
00:00 +54: /home/tung/dev/sos_safe_family/test/sos_test.dart: Tích hợp ReplayGuard vào luồng nhận SOS (handleIncomingSos) gói SOS gửi lại cùng nonce bị từ chối với duplicateNonce
00:00 +55: /home/tung/dev/sos_safe_family/test/sos_test.dart: Tích hợp ReplayGuard vào luồng nhận SOS (handleIncomingSos) gói SOS cũ hơn AppConstants.sosExpiresAfter bị từ chối với expired
00:00 +56: /home/tung/dev/sos_safe_family/test/sos_test.dart: Tích hợp ReplayGuard vào luồng nhận SOS (handleIncomingSos) gói SOS bị can thiệp ciphertext bị từ chối bởi MAC
00:00 +57: /home/tung/dev/sos_safe_family/test/sos_test.dart: Tích hợp ReplayGuard vào luồng nhận SOS (handleIncomingSos) ReplayGuard từ chối gói tin hợp lệ trước khi tốn công giải mã
00:00 +58: /home/tung/dev/sos_safe_family/test/trip_share_test.dart: TripShareService — Sprint 5A chia sẻ hành trình generateCode() sinh chuỗi 6 chữ số ngẫu nhiên
00:00 +59: /home/tung/dev/sos_safe_family/test/trip_share_test.dart: TripShareService — Sprint 5A chia sẻ hành trình hashTripCode() băm SHA-256 thành chuỗi hex 64 ký tự
00:00 +60: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:00 +61: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +62: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +63: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +64: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +65: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +65: /home/tung/dev/sos_safe_family/test/emergency_bypass_test.dart: Emergency Bypass Architecture & Scoped Gate Zero Barrier: Bản đồ & SOS luôn mở khẩn cấp mà không bị chặn
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] activateSos Firestore error: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Lỗi resolveSos lên Firestore: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +66: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +66: /home/tung/dev/sos_safe_family/test/emergency_bypass_test.dart: Emergency Bypass Architecture & Scoped Gate Scoped Gate: Cho phép bật/tắt khoá nhạy cảm và cờ FLAG_SECURE
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +67: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +67: /home/tung/dev/sos_safe_family/test/emergency_bypass_test.dart: Emergency Bypass Architecture & Scoped Gate BiometricService: Quản lý phiên mở khoá (session-based unlock)
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +68: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +68: /home/tung/dev/sos_safe_family/test/emergency_bypass_test.dart: Emergency Bypass Architecture & Scoped Gate BiometricService: Tự động khoá lại sau sessionTimeout khi background
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +69: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +69: /home/tung/dev/sos_safe_family/test/emergency_bypass_test.dart: Emergency Bypass Architecture & Scoped Gate TamperReport: Đánh giá độ tin cậy thiết bị dựa trên Root & Mock GPS
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +70: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +71: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +72: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +73: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +74: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +75: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +76: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +77: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +78: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +79: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +80: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +81: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +82: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +83: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +83: /home/tung/dev/sos_safe_family/test/security_attack_suite_test.dart: ATK-03b ReplayGuard tích hợp vào SosService & AppState AppState.receiveIncomingSos: gói tin hợp lệ kích hoạt cảnh báo và ghi audit log
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +84: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +84: /home/tung/dev/sos_safe_family/test/auth_key_provisioning_test.dart: M8 Key Provisioning & Android Keystore integration tests Tự động sinh cặp khóa X25519 và lưu vào Keystore khi lần đầu đăng nhập
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: google_user_test_123
00:01 +84: /home/tung/dev/sos_safe_family/test/security_attack_suite_test.dart: ATK-03b ReplayGuard tích hợp vào SosService & AppState AppState.receiveIncomingSos: replay bị từ chối, không kích hoạt, ghi cảnh báo tấn công vào audit log
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +85: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +85: /home/tung/dev/sos_safe_family/test/auth_key_provisioning_test.dart: M8 Key Provisioning & Android Keystore integration tests Tự động sinh cặp khóa X25519 và lưu vào Keystore khi lần đầu đăng nhập
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +86: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +87: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +88: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +88: /home/tung/dev/sos_safe_family/test/auth_key_provisioning_test.dart: M8 Key Provisioning & Android Keystore integration tests Tái sử dụng khóa X25519 đã có trong Keystore ở lần đăng nhập tiếp theo (Idempotent)
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: google_user_returning_456
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +88: /home/tung/dev/sos_safe_family/test/security_attack_suite_test.dart: ATK-04 Mock GPS spoofing AppState: nhận Position mock -> isMockGps & cảnh báo toàn vẹn
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +88: /home/tung/dev/sos_safe_family/test/auth_key_provisioning_test.dart: M8 Key Provisioning & Android Keystore integration tests Tái sử dụng khóa X25519 đã có trong Keystore ở lần đăng nhập tiếp theo (Idempotent)
[AuthService] Đã tìm thấy khóa X25519 sẵn có trong Keystore cho UID: google_user_returning_456
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +89: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +90: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +90: /home/tung/dev/sos_safe_family/test/auth_key_provisioning_test.dart: M8 Key Provisioning & Android Keystore integration tests X25519 Key Agreement (ECDH) giữa 2 người dùng tạo ra cùng Shared Secret
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: user_alice
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: user_bob
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +91: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +91: /home/tung/dev/sos_safe_family/test/auth_key_provisioning_test.dart: M8 Key Provisioning & Android Keystore integration tests Xóa khóa an toàn khi người dùng thu hồi tài khoản
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: user_to_delete
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +92: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +93: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +94: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +94: /home/tung/dev/sos_safe_family/test/family_circle_member_test.dart: Family Circle & Dynamic Members Management Tests Danh sách thành viên ban đầu hoàn toàn rỗng (đã xóa mặc định)
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +95: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +96: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +96: /home/tung/dev/sos_safe_family/test/family_circle_member_test.dart: Family Circle & Dynamic Members Management Tests sendInvitation gửi lời mời và khóa vị trí cho đến khi đối phương chấp thuận
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Tra cứu user theo email: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +96: /home/tung/dev/sos_safe_family/test/crypto_benchmark_test.dart: M6 Crypto benchmark đo hiệu năng ECDH/X25519, AES-256-GCM và SHA-256

==============================================================================
  BẢNG BENCHMARK MẬT MÃ — MILESTONE 6 (300 vòng lặp)
==============================================================================
Thao tác                                 TB (ms)     Tổng (ms)       ops/s
------------------------------------------------------------------------------
ECDH X25519 (deriveSharedKey)             1.0110        303.29         989
AES-256-GCM encrypt (vị trí SOS)          0.1748         52.43        5722
AES-256-GCM decrypt (vị trí SOS)          0.0912         27.35       10970
SHA-256 (mã chia sẻ 6 số)                 0.0567         17.02       17623
------------------------------------------------------------------------------
Ngưỡng an toàn thời gian thực: mỗi thao tác < 10.0 ms
==============================================================================

00:01 +97: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +98: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +99: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +100: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +100: /home/tung/dev/sos_safe_family/test/family_circle_member_test.dart: Family Circle & Dynamic Members Management Tests receiveIncomingInvitation nhận lời mời và cho phép từ chối hoặc chấp thuận
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +101: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +101: /home/tung/dev/sos_safe_family/test/family_circle_member_test.dart: Family Circle & Dynamic Members Management Tests addFamilyMember nhiều thành viên và tự động cấp màu sắc & tọa độ
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +102: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +103: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +103: /home/tung/dev/sos_safe_family/test/family_circle_member_test.dart: Family Circle & Dynamic Members Management Tests toggleMemberSharing thay đổi trạng thái chia sẻ vị trí
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +104: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +104: /home/tung/dev/sos_safe_family/test/family_circle_member_test.dart: Family Circle & Dynamic Members Management Tests removeFamilyMember xóa thành viên khỏi danh sách
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:01 +105: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +105: /home/tung/dev/sos_safe_family/test/crypto_benchmark_test.dart: M6 Crypto benchmark thời gian mã hóa/giải mã tin nhắn chat E2EE < 10ms
AES-256-GCM chat decrypt: TB 0.0812ms (300 vòng lặp)
00:01 +106: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:01 +107: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +107: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 1. Vòng đời SOS active -> resolved trên Firestore giữa 2 máy
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_tung_ct070161_kma_edu_vn
00:02 +107: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 1. Thành viên mới không có toạ độ hoặc pin bịa (null)
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Tra cứu user theo email: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +107: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 1. Vòng đời SOS active -> resolved trên Firestore giữa 2 máy
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_vu_ct070165_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +108: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +108: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 2. Audit log ban đầu rỗng, không chứa placeholder giờ cố định
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +109: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +109: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 3. Nhập sai mã mời hoặc mã không tồn tại thì không tạo member
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] connectWithPairingCode Firestore error: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +109: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 1. Vòng đời SOS active -> resolved trên Firestore giữa 2 máy
[AppState] activateSos Firestore error: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +110: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +110: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 4. generatePairingCode sinh mã ngẫu nhiên 6 chữ số và lưu vào state
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] generatePairingCode Firestore skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] generatePairingCode Firestore skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +111: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +111: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 1. Vòng đời SOS active -> resolved trên Firestore giữa 2 máy
[AppState] Lỗi thỏa thuận ECDH X25519 cho SOS/Vị trí: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Lỗi resolveSos lên Firestore: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +112: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +112: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 2. Gói tin SOS sai MAC (bị can thiệp trên đường truyền) bị từ chối và ghi Audit Log
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +113: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +113: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 3. Receiver bỏ qua sự kiện SOS của chính mình (senderUid == myUid)
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_tung_ct070161_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +114: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +115: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +116: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +117: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +118: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +118: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 4. Kiểm thử hiển thị UI Banner SOS cho cả 2 máy (Gửi & Nhận)
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_tung_ct070161_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_vu_ct070165_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] activateSos Firestore error: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +118: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:02 +119: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +120: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +121: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +122: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +123: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +124: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +125: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +126: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:02 +127: /home/tung/dev/sos_safe_family/test/widget_test.dart: App renders the bottom navigation and main screens
00:03 +127: /home/tung/dev/sos_safe_family/test/sos_cross_device_test.dart: M17 Cross-Device Key Synchronization & SOS/Location Decryption Tests 1. Hai máy trong cùng vòng tròn tự tính ra circleRoomId và khóa phiên đối xứng giống hệt nhau
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +127: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 4. Kiểm thử hiển thị UI Banner SOS cho cả 2 máy (Gửi & Nhận)
[AppState] ⚠️ Fallback sử dụng khóa vòng tròn đối xứng: sos_safe_family_global_demo_key
00:03 +127: /home/tung/dev/sos_safe_family/test/sos_cross_device_test.dart: M17 Cross-Device Key Synchronization & SOS/Location Decryption Tests 1. Hai máy trong cùng vòng tròn tự tính ra circleRoomId và khóa phiên đối xứng giống hệt nhau
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_tung_ct070161_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_vu_ct070165_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Lỗi thỏa thuận ECDH X25519 cho SOS/Vị trí: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] ⚠️ Fallback sử dụng khóa vòng tròn đối xứng: circle_test_uid_tung_ct070161_kma_edu_vn___test_uid_vu_ct070165_kma_edu_vn
[AppState] Lỗi thỏa thuận ECDH X25519 cho SOS/Vị trí: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] ⚠️ Fallback sử dụng khóa vòng tròn đối xứng: circle_test_uid_tung_ct070161_kma_edu_vn___test_uid_vu_ct070165_kma_edu_vn
00:03 +128: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI
00:03 +129: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI
00:03 +129: /home/tung/dev/sos_safe_family/test/widget_test.dart: Tapping the SOS button requires a long press
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +129: /home/tung/dev/sos_safe_family/test/sos_cross_device_test.dart: M17 Cross-Device Key Synchronization & SOS/Location Decryption Tests 2. Máy A gửi SOS -> Máy B giải mã thành công tọa độ GPS và tên người gửi không bị skip
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_tung_ct070161_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_vu_ct070165_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Lỗi thỏa thuận ECDH X25519 cho SOS/Vị trí: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +129: /home/tung/dev/sos_safe_family/test/cross_device_chat_sos_test.dart: Cross-Device Chat & SOS Synchronization with Firebase UID (M17) 1. Hai tài khoản CÙNG displayName "Tùng Phạm Văn" tính ra CHÍNH XÁC cùng chatId dựa trên Firebase UID
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +129: /home/tung/dev/sos_safe_family/test/sos_cross_device_test.dart: M17 Cross-Device Key Synchronization & SOS/Location Decryption Tests 2. Máy A gửi SOS -> Máy B giải mã thành công tọa độ GPS và tên người gửi không bị skip
[AppState] activateSos Firestore error: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Lỗi thỏa thuận ECDH X25519 cho SOS/Vị trí: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +130: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI
00:03 +130: /home/tung/dev/sos_safe_family/test/sos_cross_device_test.dart: M17 Cross-Device Key Synchronization & SOS/Location Decryption Tests 3. Đồng bộ vị trí thời gian thực (Location Sharing): Máy A mã hóa -> Máy B giải mã đúng tọa độ
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_tung_ct070161_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_vu_ct070165_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +131: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI
00:03 +131: /home/tung/dev/sos_safe_family/test/sos_cross_device_test.dart: M17 Cross-Device Key Synchronization & SOS/Location Decryption Tests 3. Đồng bộ vị trí thời gian thực (Location Sharing): Máy A mã hóa -> Máy B giải mã đúng tọa độ
[AppState] Lỗi thỏa thuận ECDH X25519 cho SOS/Vị trí: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Lỗi thỏa thuận ECDH X25519 cho SOS/Vị trí: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +132: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI
00:03 +133: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI
00:03 +133: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 4. Kiểm thử hiển thị UI Banner SOS cho cả 2 máy (Gửi & Nhận)
[AppState] Lỗi resolveSos lên Firestore: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +133: /home/tung/dev/sos_safe_family/test/sos_cross_device_test.dart: M17 Cross-Device Key Synchronization & SOS/Location Decryption Tests 4. Đồng bộ sự kiện Geofence: Máy A phát sự kiện -> Máy B giải mã nguyên vẹn
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_tung_ct070161_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: test_uid_vu_ct070165_kma_edu_vn
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +134: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI
00:03 +134: /home/tung/dev/sos_safe_family/test/cross_device_chat_sos_test.dart: Cross-Device Chat & SOS Synchronization with Firebase UID (M17) 1. Hai tài khoản CÙNG displayName "Tùng Phạm Văn" tính ra CHÍNH XÁC cùng chatId dựa trên Firebase UID
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: uid_A_tung_1
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: uid_B_tung_2
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +135: /home/tung/dev/sos_safe_family/test/no_fake_data_test.dart: M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật 5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI
00:03 +135: /home/tung/dev/sos_safe_family/test/cross_device_chat_sos_test.dart: Cross-Device Chat & SOS Synchronization with Firebase UID (M17) 2. ECDH X25519 giữa keypair A và public key B vs keypair B và public key A cho ra CÙNG MỘT KHÓA AES-256 (32 bytes)
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +136: /home/tung/dev/sos_safe_family/test/sos_relay_test.dart: M12 SOS Relay & Multi-device Lifecycle Tests 4. Kiểm thử hiển thị UI Banner SOS cho cả 2 máy (Gửi & Nhận)
00:03 +136: /home/tung/dev/sos_safe_family/test/cross_device_chat_sos_test.dart: Cross-Device Chat & SOS Synchronization with Firebase UID (M17) 2. ECDH X25519 giữa keypair A và public key B vs keypair B và public key A cho ra CÙNG MỘT KHÓA AES-256 (32 bytes)
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: uid_A_tung_1
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: uid_B_tung_2
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +137: /home/tung/dev/sos_safe_family/test/widget_test.dart: Tapping the SOS button requires a long press
00:03 +138: /home/tung/dev/sos_safe_family/test/widget_test.dart: Tapping the SOS button requires a long press
00:03 +138: /home/tung/dev/sos_safe_family/test/cross_device_chat_sos_test.dart: Cross-Device Chat & SOS Synchronization with Firebase UID (M17) 3. Người A mã hóa tin nhắn chat bằng AES-256-GCM -> Người B giải mã thành công ra đúng plaintext
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: uid_A_tung_1
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: uid_B_tung_2
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +139: /home/tung/dev/sos_safe_family/test/widget_test.dart: Tapping the SOS button requires a long press
00:03 +139: /home/tung/dev/sos_safe_family/test/cross_device_chat_sos_test.dart: Cross-Device Chat & SOS Synchronization with Firebase UID (M17) 4. Người A gọi activateSos -> Người B nhận và giải mã đúng lat, lng, senderName dù cả hai trùng displayName
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: uid_A_tung_1
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: uid_B_tung_2
[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Lỗi thỏa thuận ECDH X25519 cho SOS/Vị trí: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] activateSos Firestore error: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Lỗi thỏa thuận ECDH X25519 cho SOS/Vị trí: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +140: /home/tung/dev/sos_safe_family/test/widget_test.dart: Tapping the SOS button requires a long press
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:04 +140: /home/tung/dev/sos_safe_family/test/member_uid_normalize_test.dart: fake member ids are rejected while real Firebase UIDs are kept
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:04 +140: /home/tung/dev/sos_safe_family/test/sos_key_symmetric_test.dart: same peer pair derives the same SOS key regardless of ordering
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:04 +141: /home/tung/dev/sos_safe_family/test/widget_test.dart: Tapping the SOS button requires a long press
00:04 +142: /home/tung/dev/sos_safe_family/test/widget_test.dart: Tapping the SOS button requires a long press
00:04 +143: /home/tung/dev/sos_safe_family/test/widget_test.dart: Tapping the SOS button requires a long press
00:04 +144: /home/tung/dev/sos_safe_family/test/widget_test.dart: Countdown shows 3-2-1 and HỦY
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:04 +145: /home/tung/dev/sos_safe_family/test/widget_test.dart: Countdown completing activates the emergency banner
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] activateSos Firestore error: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:04 +146: /home/tung/dev/sos_safe_family/test/widget_test.dart: "TÔI ĐÃ AN TOÀN" resolves the emergency state
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] activateSos Firestore error: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] Lỗi resolveSos lên Firestore: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:04 +147: /home/tung/dev/sos_safe_family/test/widget_test.dart: Bản đồ hiển thị vùng an toàn và danh sách vùng
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initSosListener skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] initLocationListeners skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:05 +148: /home/tung/dev/sos_safe_family/test/widget_test.dart: signOut clears family member state to isolate next account
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:05 +149: All tests passed! -> 0; ## main...origin/main [đứng trước 2]
 M bao_cao_cong_viec/BC_M19_MemberUidNormalize_20261109.md -> 0; 0bd5887 feat(m19): normalize member.id to real Firebase UID, single-field invitation queries, symmetric SOS keys
6a80490 feat(m18): diagnostic indicators + invite lifecycle fixes
5ed332e feat(m18): cross-device chat diagnostic indicators and connection flow
d2b657d docs(m17): update fresh cross-device chat screenshot -> 0.
- Git log -4:
  - 0bd5887c08f751b3a37d8d2ff01db699c4bb673c feat(m19): normalize member.id to real Firebase UID, single-field invitation queries, symmetric SOS keys
  - 6a8049019ea15ad5911812a4afe0770190ed0616 feat(m18): diagnostic indicators + invite lifecycle fixes
  - 5ed332e feat(m18): cross-device chat diagnostic indicators and connection flow
  - d2b657d docs(m17): update fresh cross-device chat screenshot
- Git status: ## main...origin/main [đứng trước 2]
 M bao_cao_cong_viec/BC_M19_MemberUidNormalize_20261109.md sau push sẽ sạch.
- Nghiệm thu: PASS qua analyze/test; chưa nghiệm thu tay 2 máy. Trước demo phải build APK mới + reset dữ liệu Firebase Console để tránh dữ liệu cũ chồng.
- Bằng chứng test tail: 
