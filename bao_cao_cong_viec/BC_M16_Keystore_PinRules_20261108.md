# BÁO CÁO CÔNG VIỆC: M16 - BẬT KEYSTORE THẬT, PIN FALLBACK VÀ FIRESTORE RULES

- **Ngày thực hiện:** 08/11/2026
- **Mã báo cáo:** `BC_M16_Keystore_PinRules_20261108.md`
- **Tóm tắt:** Bật `encryptedSharedPreferences: true` & `aesGcmMasterKeys`, thêm `isKeystoreBacked`, luồng PIN fallback 6 chữ số kèm SHA-256 (16-byte salt) khi thiết bị thiếu sinh trắc học, thiết lập `firestore.rules` và trường `members` trong `chats`. Toàn bộ 136/136 tests PASS.

## BẰNG CHỨNG NGHIỆM THU (RAW OUTPUT)

### 1. `git log --oneline -3`
```
f8783ce (HEAD -> main, origin/main) docs(m16): bổ sung báo cáo nghiệm thu BC_M16
5a62f39 feat(m16): keystore real config + biometric PIN fallback + firestore rules
7ebd414 docs(m15): bổ sung báo cáo nghiệm thu nhánh main BC_M15
```

### 2. `git status --short`
```
(trắng / sạch - exit code 0)
```

### 3. `flutter test 2>&1 | tail -3`
```
00:03 +135: /home/tung/dev/sos_safe_family/test/widget_test.dart: signOut clears family member state to isolate next account
[AuthService] authStateChanges offline fallback: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:03 +136: All tests passed!
```

### 4. Kiểm tra mã nguồn & file cấu hình
- `grep -n "encryptedSharedPreferences: true" lib/data/services/secure_storage_service.dart`:
```
33:/// Trên Android, cấu hình `encryptedSharedPreferences: true` và `aesGcmMasterKeys`
39:    encryptedSharedPreferences: true,
45:    encryptedSharedPreferences: true,
```
- `grep -rn "BiometricResult.unavailable" lib/main.dart`: `0 dòng (Exit code 1)`
- `test -f firestore.rules && test -f firebase.json`: `Tồn tại hợp lệ (Exit code 0)`
