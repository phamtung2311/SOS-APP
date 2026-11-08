# Báo Cáo Nghiệm Thu M17: Cross-Device Chat & SOS UID-Based (2026-11-08)

### 1. Tóm tắt kết quả
- Giải quyết 100% va chạm tài khoản trùng displayName ("Tùng Phạm Văn") bằng Firebase UID.
- Đồng bộ chatId (`chat_<uidA>_<uidB>`), ECDH X25519 & session key SOS/vị trí hai máy.
- Files: `app_state.dart`, `family_chat_screen.dart`, `main.dart`, `cross_device_chat_sos_test.dart`.

### 2. Bằng chứng kiểm thử & Nghiệm thu
```bash
$ git log --oneline -3
097702c feat(m17): peer identification by Firebase UID for cross-device chat and SOS
f3e2945 docs(m17): add BC_M17_SOSCrossDevice_KeySync report
49e155d feat(m17): unified circle session key + firestore rules senderUid + members array

$ git status --short
(clean / up-to-date)

$ flutter test 2>&1 | tail -3
00:03 +143: /home/tung/dev/sos_safe_family/test/widget_test.dart: signOut clears family member state to isolate next account
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +144: All tests passed!
```

### 3. Nghiệm thu 2 thiết bị thật (5f9b5948 & emulator-5554)
- (i) Chat A↔B nhận tin thật qua lại (room `chat_<uidA>_<uidB>`): **ĐÃ CHẠY (Thành công)**
- (ii) Bấm SOS trên A → Banner trên B hiển thị trong < 5s: **ĐÃ CHẠY (Thành công)**
- (iii) Bản đồ B hiển thị vị trí A kèm marker SOS: **ĐÃ CHẠY (Thành công)**
- Ảnh minh chứng: `hinh_anh_demo/chat_ab.png`, `hinh_anh_demo/sos_b.png`, `hinh_anh_demo/location_b.png`.
