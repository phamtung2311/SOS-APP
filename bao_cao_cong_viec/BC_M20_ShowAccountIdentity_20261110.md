# Báo Cáo M20: Show Account Identity & Tighten UID Validation (2026-11-10)

### 1. Tóm tắt kết quả
- Hiển thị `email` + `uid` (bấm để copy) tại màn **Cá nhân**, email bản thân ở header **Vòng tròn gia đình**, và `myEmail`/`peerEmail` trên header badge **Chat**.
- Siết chặt `isUidLike()` (`[A-Za-z0-9]{20,}`, cấm `_`, `-`, `uid_`, `mock_`, `anonymous`) và dùng `isSyntheticMemberUid()` loại/tra lại mọi member ID giả.
- Files: `lib/core/app_state.dart`, `lib/main.dart`, `lib/presentation/screens/family_chat_screen.dart`, `test/member_uid_normalize_test.dart`, `test/sos_cross_device_test.dart`, `test/cross_device_chat_sos_test.dart`.

### 2. Bằng chứng thực thi (Raw output)
```bash
$ git log --oneline -3
dc8739d (HEAD -> main) feat(m20): show account identity in UI, tighten isUidLike, drop synthetic member ids
9ca42eb (origin/main, origin/HEAD) feat(m19): normalize member.id to real Firebase UID, single-field invitation queries, symmetric SOS keys
6a80490 feat(m18): diagnostic indicators + invite lifecycle fixes

$ git status --short
(clean)

$ flutter analyze 2>&1 | tail -2
Analyzing sos_safe_family...
No issues found! (ran in 3.6s)

$ flutter test 2>&1 | tail -3
00:03 +150: /home/tung/dev/sos_safe_family/test/widget_test.dart: signOut clears family member state to isolate next account
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:04 +151: All tests passed!
```

### 3. Trạng thái & Nghiệm thu
- Hoàn tất 100% 3 hạng mục; 151/151 test PASS, 0 lỗi analyze; đã nạp APK M20 lên 2 emulator (`5554` Hà Nội & `5556` TP.HCM).
