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

void main() {
  test('isUidLike strictly matches real Firestore UIDs and rejects fake/underscore IDs', () {
    expect(AppState.isUidLike('IsJZEdvlR4Wp4dTXxEbd6Oeqcuy2'), isTrue);
    expect(AppState.isUidLike('uid_phamvantunghn2b_gmail_com'), isFalse);
    expect(AppState.isUidLike('mock_uid_x'), isFalse);
    expect(AppState.isUidLike('anonymous'), isFalse);
    expect(AppState.isUidLike('abc_def_123'), isFalse);
  });

  test('sendInvitation blocks inviting self email to avoid same-account loop', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final appState = AppState(
      authService: AuthService(
        cryptoService: CryptoService(),
        secureStorage: _InMemoryStorage(),
      ),
    );
    await appState.signInWithTestAccount(
      email: 'tungtest@example.com',
      displayName: 'Tùng Phạm Văn',
    );

    final err = await appState.sendInvitation(
      name: 'Tùng Phạm Văn',
      relation: 'Người thân',
      email: 'TUNGTest@example.com',
    );
    expect(err, equals('Không thể tự kết nối với chính mình'));
    expect(appState.familyMembers, isEmpty);
  });

  test('fake member ids are rejected while real Firebase UIDs are kept', () {
    final appState = AppState();

    appState.addFamilyMember(
      name: 'Người lạ',
      relation: 'Khác',
      email: 'bad@example.com',
      uid: 'uid_bad_example_com',
      status: MemberConnectionStatus.accepted,
    );
    expect(appState.familyMembers, isEmpty,
        reason: 'member.id giả được sinh từ email không được chấp nhận');

    appState.addFamilyMember(
      name: 'Người thân',
      relation: 'Chị em',
      email: 'good@example.com',
      uid: 'Z9fY2c3L7uQ4pKx1J8mN',
      status: MemberConnectionStatus.accepted,
    );

    expect(appState.familyMembers, hasLength(1));
    expect(appState.familyMembers.first.id, equals('Z9fY2c3L7uQ4pKx1J8mN'));
  });

  test('acceptInvitation matches only the exact peer invitation doc in mock Firestore data', () {
    final docs = <Map<String, dynamic>>[
      {'toEmail': 'me@example.com', 'fromUid': 'peer_uid_2', 'status': 'pending'},
      {'toEmail': 'me@example.com', 'fromUid': 'peer_uid_1', 'status': 'pending'},
      {'fromUid': 'my_uid_1', 'toUid': 'peer_uid_1', 'status': 'pending'},
      {'fromUid': 'my_uid_1', 'toUid': 'peer_uid_9', 'status': 'pending'},
    ];

    final matches = docs.where((doc) {
      return AppState.matchesInvitationForAcceptance(
        doc,
        currentUserEmail: 'me@example.com',
        currentUserUid: 'my_uid_1',
        targetId: 'peer_uid_1',
      );
    }).toList();

    expect(matches, hasLength(2));
    expect(matches.any((doc) => doc['fromUid'] == 'peer_uid_1'), isTrue);
    expect(matches.any((doc) => doc['toUid'] == 'peer_uid_1'), isTrue);
  });
}
