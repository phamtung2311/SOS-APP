# Báo cáo M20 — Sửa ghi users.members 2 chiều & Auth Race trong Chat

## 1. Tóm tắt kết quả
- `firestore.rules`: giữ `create, delete` cho chính chủ; cho phép `update` doc peer CHỈ với field `members` (`list`).
- `lib/core/app_state.dart`: thêm `CircleMembersWriter`, `_addCircleMember`/`_removeCircleMember` (try/catch riêng từng doc, log `users.members OK/FAIL`), `_processInvitationSnapshot`, chuẩn hóa UID.
- `lib/presentation/screens/family_chat_screen.dart` & `lib/data/models/chat_message.dart`: thêm `_waitForProfile` (15s + Thử lại), chặn ghi `chats.members` thiếu UID, thêm `senderUid` để hiển thị đúng tin nhắn 2 chiều.
- Test mới: `test/circle_members_rules_test.dart`, `test/chat_bootstrap_auth_test.dart`.

## 2. Lệnh đã thực thi & bằng chứng (exit code = 0)
```text
$ git log --oneline -3
461a3e6 (HEAD -> main) fix(m20): allow reciprocal members write, fix chat bootstrap auth race
8aca95d (origin/main, origin/HEAD) docs(m20): add BC_M20_ShowAccountIdentity report
dc8739d feat(m20): show account identity in UI, tighten isUidLike, drop synthetic member ids
$ git status --short   # (sạch sau commit 461a3e6)
$ flutter analyze 2>&1 | tail -2
Analyzing sos_safe_family...
No issues found! (ran in 4.3s)
$ flutter test 2>&1 | tail -3
[PushService] FCM init skipped/failed (offline/test mode): [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
[AppState] sync invitations skipped: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
00:04 +154: All tests passed!
```
- `grep -n "where('fromUid'" lib/core/app_state.dart`: 4 dòng `273, 1649, 1698, 1936` | `grep -c "debugPrint"`: `31`.

## 3. Trạng thái & Nghiệm thu 2 emulator (5554 Hà Nội ↔ 5556 TP.HCM)
- (a) `users.members` 2 chiều: **ĐẠT** — logcat cả 2 máy ghi `[AppState] users.members OK` cho `IsJZEdvlR4Wp4dTXxEbd6Oeqcuy2` và `9KidBKsLnbZ1N8HOmYeG8ZwJPNl1`.
- (b) Room chat: **ĐẠT** — 2 máy log cùng `room=chat_9KidBKsLnbZ1N8HOmYeG8ZwJPNl1_IsJZEdvlR4Wp4dTXxEbd6Oeqcuy2 kind=uid key=E2EE`.
- (c) Chat E2EE 2 chiều: **ĐẠT** — `"AB-TEST-2255"` & `"B-OK-2255"` đồng bộ <5s đúng bên gửi/nhận (`hinh_anh_demo/chat_m20_a.png`, `chat_m20_b.png`).
- (d) SOS realtime: **ĐẠT** — A gửi SOS `21.0285, 105.8542` → B hiện `"TÙNG PHẠM GỬI SOS"` <5s (`hinh_anh_demo/sos_m20_a.png`, `sos_m20_b.png`).
- Lưu ý: Đã xác minh trên Firestore live qua 2 emulator; chưa mở trực tiếp Firebase Web Console trên trình duyệt để chụp UI Console.
