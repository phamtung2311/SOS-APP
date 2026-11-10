import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/services/auth_service.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/secure_storage_service.dart';

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

class _WriteLogEntry {
  final String docUid;
  final String targetMemberUid;
  final bool add;
  _WriteLogEntry(this.docUid, this.targetMemberUid, this.add);
}

class _FakeCircleMembersWriter implements CircleMembersWriter {
  final Map<String, Set<String>> usersMembers = {};
  final List<_WriteLogEntry> writeCalls = [];

  @override
  Future<void> updateUserMembers({
    required String docUid,
    required String targetMemberUid,
    required bool add,
  }) async {
    writeCalls.add(_WriteLogEntry(docUid, targetMemberUid, add));
    final current = usersMembers.putIfAbsent(docUid, () => <String>{});
    if (add) {
      current.add(targetMemberUid);
    } else {
      current.remove(targetMemberUid);
    }
  }
}

void main() {
  test(
    'acceptInvitation writes reciprocal members array to users/A and users/B, and removeFamilyMember removes both',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      const uidA = 'IsJZEdvlR4Wp4dTXxEbd6Oeqcuy2';
      const uidB = '9KidBKsLnbZ1N8HOmYeG8ZwJPNl1';
      const emailA = 'phamtunghn11@gmail.com';
      const emailB = 'phamvantunghn2b@gmail.com';

      final fakeWriter = _FakeCircleMembersWriter();
      final appStateA = AppState(
        authService: AuthService(
          cryptoService: CryptoService(),
          secureStorage: _InMemoryStorage(),
        ),
        circleMembersWriter: fakeWriter,
      );

      await appStateA.signInWithTestAccount(
        uid: uidA,
        email: emailA,
        displayName: 'Tùng Phạm Văn',
      );

      appStateA.addFamilyMember(
        name: 'Tùng Phạm Văn',
        relation: 'Người thân',
        email: emailB,
        uid: uidB,
        status: MemberConnectionStatus.pendingIncoming,
      );

      fakeWriter.writeCalls.clear();

      // 1. A accept lời mời của B -> 2 lần ghi đúng doc (users/A chứa B, users/B chứa A)
      await appStateA.acceptInvitation(uidB);

      final acceptDocs = fakeWriter.writeCalls
          .where((c) => c.add)
          .map((c) => c.docUid)
          .toSet();
      expect(acceptDocs, containsAll(<String>[uidA, uidB]));
      expect(fakeWriter.usersMembers[uidA], contains(uidB));
      expect(fakeWriter.usersMembers[uidB], contains(uidA));

      // 2. A xóa B -> 2 lần ghi arrayRemove -> cả 2 doc đều mất nhau
      fakeWriter.writeCalls.clear();
      await appStateA.removeFamilyMember(uidB);

      final removeDocs = fakeWriter.writeCalls
          .where((c) => !c.add)
          .map((c) => c.docUid)
          .toSet();
      expect(removeDocs, containsAll(<String>[uidA, uidB]));
      expect(fakeWriter.usersMembers[uidA], isNot(contains(uidB)));
      expect(fakeWriter.usersMembers[uidB], isNot(contains(uidA)));
    },
  );
}
