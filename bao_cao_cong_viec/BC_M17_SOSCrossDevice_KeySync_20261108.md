# Báo Cáo Milestone 17: Đồng Bộ Khóa SOS & Firestore Rules

- **Nhiệm vụ:** Thống nhất khóa phiên vòng tròn gia đình (`circleRoomId`), sửa rules sang `senderUid`, ghi `users/{uid}.members`.
- **Files:** `lib/core/app_state.dart`, `lib/data/services/location_share_service.dart`, `firestore.rules`, `test/sos_cross_device_test.dart`.
- **Commit:** `49e155d` trên `origin/main` (git sạch, 140/140 tests pass).

### Bằng Chứng Nghiệm Thu (Raw Output):
1. **`flutter analyze`:** `No issues found! (ran in 2.7s)`
2. **`flutter test`:** `00:04 +140: All tests passed!`
3. **`grep -rn "arrayUnion\|arrayRemove" lib/`:**
```
lib/core/app_state.dart:1084: 'members': FieldValue.arrayUnion([fromUid]),
lib/core/app_state.dart:1087: 'members': FieldValue.arrayUnion([myUid]),
lib/core/app_state.dart:1245: 'members': FieldValue.arrayUnion([fromUid]),
lib/core/app_state.dart:1285: 'members': FieldValue.arrayUnion([myUid]),
lib/core/app_state.dart:1297: 'members': FieldValue.arrayUnion(memberUids.toList()),
lib/core/app_state.dart:1321: 'members': FieldValue.arrayRemove([id]),
lib/core/app_state.dart:1325: 'members': FieldValue.arrayRemove([myUid]),
```
4. **`grep -n "senderUid\|userId\|senderId" firestore.rules` (Không còn userId/senderId):**
```
39:  allow create: if isAuthenticated() && request.resource.data.senderUid == request.auth.uid;
41:  (resource.data.senderUid == request.auth.uid || resource.data.recipientUid == request.auth.uid);
65:  request.resource.data.senderUid == request.auth.uid;
69:  resource.data.senderUid == request.auth.uid ||
70:  request.auth.uid in get(/databases/$(database)/documents/users/$(resource.data.senderUid)).data.members
76:  request.resource.data.senderUid == request.auth.uid;
80:  resource.data.senderUid == request.auth.uid ||
81:  request.auth.uid in get(/databases/$(database)/documents/users/$(resource.data.senderUid)).data.members
```
5. **`git status` & Log:**
```
Trên nhánh main (cập nhật với origin/main). Thư mục làm việc sạch sẽ.
commit 49e155d feat(m17): unified circle session key + firestore rules senderUid + members array
Logcat sync members: [AppState] syncCircleMembersToFirestore hoàn tất: {PgtAhXr7naS4OXmWJ7wE, 9KidBKsLnbZ1N8HOmYeG8ZwJPNl1}
```
*Ghi chú Deploy Rules:* Chạy `firebase deploy --only firestore:rules` trên console để đồng bộ rules lên Firebase.
