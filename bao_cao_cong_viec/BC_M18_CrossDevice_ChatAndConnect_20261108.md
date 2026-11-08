## 1. Git / repo evidence
- `git log --oneline -3`: d2b657d, cca9c3a, 097702c
- `git status --short`: modified app_state.dart, main.dart, family_chat_screen.dart; new test/cross_device_chat_test.dart

## 2. Static analysis evidence
- `flutter analyze`: No issues found!
- `flutter test`: 00:03 +146: All tests passed!

## 3. Auto-accept / pending fix evidence
- `connectWithPairingCode` now explicitly marks code-based connect as 1-way/instant; email route remains pending until `acceptInvitation`.
- `cancelled` handling added in invitation state and removal flow to prevent stale members resurfacing.
- `simulatePeerApproval` remains gated by `kDebugMode` only.

## 4. Cross-device chat room fix evidence
- UID-based room generation now uses `AppState.buildChatRoomId` with real UIDs; email fallback only when no user doc exists.
- `FamilyChatScreen` exposes room, kind, key mode, member ID in debug header and logs `[CHAT] room=... kind=... key=...`.
- Regression: `flutter test test/cross_device_chat_test.dart`: 2 tests passed.

## 5. Two-device live verification status
- a) Auto-accept: CHƯA verify trên 2 máy thật trong môi trường này.
- b) 2 máy cùng room UID: ĐẠT theo code + test, CHƯA verify trên device thật.
- c) A->B tin duy nhất đúng <5s: CHƯA verify trên 2 máy thật trong môi trường này.
- Hướng dẫn: build lại trên cả 2 máy với `flutter clean && flutter run` trước khi kiểm tra; nếu chạy APK cũ, sẽ thấy room/email fallback và “giống nhau” là sai.
