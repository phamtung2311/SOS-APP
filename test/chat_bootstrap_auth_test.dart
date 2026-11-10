import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/services/auth_service.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/secure_storage_service.dart';
import 'package:sos_safe_family/presentation/screens/family_chat_screen.dart';

class _InMemoryStorage extends SecureStorageService {
  final Map<String, String> _mem = {};
  @override
  Future<void> saveUserPrivateKey(String uid, String val) async => _mem['p_$uid'] = val;
  @override
  Future<String?> getUserPrivateKey(String uid) async => _mem['p_$uid'];
  @override
  Future<void> saveUserPublicKey(String uid, String val) async => _mem['pub_$uid'] = val;
  @override
  Future<String?> getUserPublicKey(String uid) async => _mem['pub_$uid'];
}

AppState _makeState() => AppState(
      authService: AuthService(
        cryptoService: CryptoService(),
        secureStorage: _InMemoryStorage(),
      ),
    );

void main() {
  testWidgets(
    'when userProfile is null at initState, chat does NOT calculate email-fallback room and shows unauthenticated empty state on timeout',
    (tester) async {
      final appState = _makeState();
      expect(appState.userProfile, isNull);

      await tester.pumpWidget(
        AppScope(
          state: appState,
          child: const MaterialApp(
            home: FamilyChatScreen(
              memberName: 'Tùng Phạm Văn',
              peerEmail: 'phamvantunghn2b@gmail.com',
              memberId: '9KidBKsLnbZ1N8HOmYeG8ZwJPNl1',
              profileWaitTimeout: Duration(milliseconds: 500),
            ),
          ),
        ),
      );

      // Khi mới initState mà userProfile còn null -> tuyệt đối không rơi về chat_user_a___...
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('chat_user_a'), findsNothing);
      expect(find.textContaining('email-fallback'), findsNothing);

      // Hết thời gian chờ 500ms vẫn chưa đăng nhập -> hiện thông báo chưa đăng nhập + nút Thử lại
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.text('Chưa đăng nhập, không thể mở khóa E2EE'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    },
  );

  testWidgets(
    'when userProfile arrives after initState, both peers resolve the exact same UID-based room chat_<uidA>_<uidB>',
    (tester) async {
      const uidA = 'IsJZEdvlR4Wp4dTXxEbd6Oeqcuy2';
      const uidB = '9KidBKsLnbZ1N8HOmYeG8ZwJPNl1';
      final expectedRoom = 'chat_${uidB}_$uidA'; // sorted: 9Kid... < IsJZ...

      // 1. Máy A mở chat trước khi auth hoàn tất (userProfile null lúc initState)
      final stateA = _makeState();
      await tester.pumpWidget(
        AppScope(
          state: stateA,
          child: MaterialApp(
            home: FamilyChatScreen(
              memberName: 'Tùng Phạm Văn',
              peerEmail: 'phamvantunghn2b@gmail.com',
              memberId: uidB,
              profileWaitTimeout: const Duration(seconds: 5),
              secureStorage: _InMemoryStorage(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('chat_user_a'), findsNothing);

      // Profile A trả về muộn sau khi auth xong
      await stateA.signInWithTestAccount(
        uid: uidA,
        email: 'phamtunghn11@gmail.com',
        displayName: 'Tùng Phạm Văn',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.textContaining('room=$expectedRoom'), findsOneWidget);
      expect(find.textContaining('kind=uid'), findsOneWidget);

      // 2. Máy B mở chat với A -> phải ra CÙNG MỘT room
      final stateB = _makeState();
      await stateB.signInWithTestAccount(
        uid: uidB,
        email: 'phamvantunghn2b@gmail.com',
        displayName: 'Tùng Phạm Văn',
      );

      await tester.pumpWidget(
        AppScope(
          state: stateB,
          child: MaterialApp(
            home: FamilyChatScreen(
              memberName: 'Tùng Phạm Văn',
              peerEmail: 'phamtunghn11@gmail.com',
              memberId: uidA,
              profileWaitTimeout: const Duration(seconds: 5),
              secureStorage: _InMemoryStorage(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.textContaining('room=$expectedRoom'), findsOneWidget);
      expect(find.textContaining('kind=uid'), findsOneWidget);
    },
  );
}
