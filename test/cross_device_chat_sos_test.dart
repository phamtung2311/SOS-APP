import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/services/auth_service.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/secure_storage_service.dart';

class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> _memory = {};

  @override
  Future<void> saveUserPrivateKey(String uid, String privateKeyBase64) async {
    _memory['x25519_priv_$uid'] = privateKeyBase64;
  }

  @override
  Future<String?> getUserPrivateKey(String uid) async {
    return _memory['x25519_priv_$uid'];
  }

  @override
  Future<void> saveUserPublicKey(String uid, String publicKeyBase64) async {
    _memory['x25519_pub_$uid'] = publicKeyBase64;
  }

  @override
  Future<String?> getUserPublicKey(String uid) async {
    return _memory['x25519_pub_$uid'];
  }

  @override
  Future<void> deleteUserKeys(String uid) async {
    _memory.remove('x25519_priv_$uid');
    _memory.remove('x25519_pub_$uid');
  }
}

AppState createTestAppState(CryptoService crypto, FakeSecureStorageService storage) {
  final authService = AuthService(
    cryptoService: crypto,
    secureStorage: storage,
  );
  return AppState(
    cryptoService: crypto,
    authService: authService,
  );
}

void main() {
  group('Cross-Device Chat & SOS Synchronization with Firebase UID (M17)', () {
    late CryptoService crypto;
    late FakeSecureStorageService storageA;
    late FakeSecureStorageService storageB;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      crypto = CryptoService();
      storageA = FakeSecureStorageService();
      storageB = FakeSecureStorageService();
    });

    test('1. Hai tài khoản CÙNG displayName "Tùng Phạm Văn" tính ra CHÍNH XÁC cùng chatId dựa trên Firebase UID', () async {
      final aliceState = createTestAppState(crypto, storageA);
      final bobState = createTestAppState(crypto, storageB);

      const uidA = 'uid_A_tung_1';
      const uidB = 'uid_B_tung_2';
      const sameDisplayName = 'Tùng Phạm Văn';

      await aliceState.signInWithTestAccount(
        uid: uidA,
        email: 'phamtunghn11@gmail.com',
        displayName: sameDisplayName,
      );

      await bobState.signInWithTestAccount(
        uid: uidB,
        email: 'phamvantunghn2b@gmail.com',
        displayName: sameDisplayName,
      );

      // Cả 2 tài khoản đều mang cùng một displayName hiển thị
      expect(aliceState.userProfile?.displayName, equals(sameDisplayName));
      expect(bobState.userProfile?.displayName, equals(sameDisplayName));
      expect(aliceState.currentUserUid, equals(uidA));
      expect(bobState.currentUserUid, equals(uidB));

      // Tính toán chatId độc lập từ hai phía
      final sortedA = [aliceState.currentUserUid!, uidB]..sort();
      final chatIdFromA = 'chat_${sortedA[0]}_${sortedA[1]}';

      final sortedB = [bobState.currentUserUid!, uidA]..sort();
      final chatIdFromB = 'chat_${sortedB[0]}_${sortedB[1]}';

      // Xác minh chatId hoàn toàn đồng nhất, không bị nhầm phòng do trùng tên
      expect(chatIdFromA, equals(chatIdFromB));
      expect(chatIdFromA, equals('chat_uid_A_tung_1_uid_B_tung_2'));
    });

    test('2. ECDH X25519 giữa keypair A và public key B vs keypair B và public key A cho ra CÙNG MỘT KHÓA AES-256 (32 bytes)', () async {
      final aliceState = createTestAppState(crypto, storageA);
      final bobState = createTestAppState(crypto, storageB);

      const uidA = 'uid_A_tung_1';
      const uidB = 'uid_B_tung_2';

      final profileA = await aliceState.signInWithTestAccount(
        uid: uidA,
        email: 'phamtunghn11@gmail.com',
        displayName: 'Tùng Phạm Văn',
      );

      final profileB = await bobState.signInWithTestAccount(
        uid: uidB,
        email: 'phamvantunghn2b@gmail.com',
        displayName: 'Tùng Phạm Văn',
      );

      // Lấy private key từ Keystore và import KeyPair
      final privA = await storageA.getUserPrivateKey(uidA);
      final keyPairA = await crypto.importKeyPair(
        privateKeyB64: privA!,
        publicKeyB64: profileA.publicKeyB64,
      );

      final privB = await storageB.getUserPrivateKey(uidB);
      final keyPairB = await crypto.importKeyPair(
        privateKeyB64: privB!,
        publicKeyB64: profileB.publicKeyB64,
      );

      // Người A thỏa thuận khóa bằng Public Key của B
      final sharedKeyA = await crypto.deriveChatKeyForPeer(
        myKeyPair: keyPairA,
        theirPublicKeyB64: profileB.publicKeyB64,
      );

      // Người B thỏa thuận khóa bằng Public Key của A
      final sharedKeyB = await crypto.deriveChatKeyForPeer(
        myKeyPair: keyPairB,
        theirPublicKeyB64: profileA.publicKeyB64,
      );

      // Xác minh 2 khóa phiên khớp nhau 100% và chuẩn 32 byte AES-256
      expect(sharedKeyA, equals(sharedKeyB));
      expect(sharedKeyA.length, equals(32));
    });

    test('3. Người A mã hóa tin nhắn chat bằng AES-256-GCM -> Người B giải mã thành công ra đúng plaintext', () async {
      final aliceState = createTestAppState(crypto, storageA);
      final bobState = createTestAppState(crypto, storageB);

      final profileA = await aliceState.signInWithTestAccount(
        uid: 'uid_A_tung_1',
        email: 'phamtunghn11@gmail.com',
        displayName: 'Tùng Phạm Văn',
      );

      final profileB = await bobState.signInWithTestAccount(
        uid: 'uid_B_tung_2',
        email: 'phamvantunghn2b@gmail.com',
        displayName: 'Tùng Phạm Văn',
      );

      final privA = await storageA.getUserPrivateKey('uid_A_tung_1');
      final keyPairA = await crypto.importKeyPair(
        privateKeyB64: privA!,
        publicKeyB64: profileA.publicKeyB64,
      );

      final privB = await storageB.getUserPrivateKey('uid_B_tung_2');
      final keyPairB = await crypto.importKeyPair(
        privateKeyB64: privB!,
        publicKeyB64: profileB.publicKeyB64,
      );

      final sharedKeyA = await crypto.deriveChatKeyForPeer(
        myKeyPair: keyPairA,
        theirPublicKeyB64: profileB.publicKeyB64,
      );

      final sharedKeyB = await crypto.deriveChatKeyForPeer(
        myKeyPair: keyPairB,
        theirPublicKeyB64: profileA.publicKeyB64,
      );

      // Tin nhắn văn bản người A gửi
      const rawMessage = 'Chào Tùng B, đây là tin nhắn bảo mật E2EE giữa hai thiết bị!';

      // A mã hóa văn bản
      final payload = await crypto.encryptTextMessage(rawMessage, sharedKeyA);
      expect(payload.ciphertextBase64.isNotEmpty, isTrue);
      expect(payload.nonceBase64.isNotEmpty, isTrue);
      expect(payload.macBase64.isNotEmpty, isTrue);

      // Mô phỏng payload truyền qua mạng / Firestore
      final serialized = {
        'ciphertextBase64': payload.ciphertextBase64,
        'nonceBase64': payload.nonceBase64,
        'macBase64': payload.macBase64,
      };

      final receivedPayload = EncryptedPayload.fromBase64(
        ciphertextBase64: serialized['ciphertextBase64']!,
        nonceBase64: serialized['nonceBase64']!,
        macBase64: serialized['macBase64']!,
      );

      // B giải mã tin nhắn bằng khóa đã thỏa thuận
      final decryptedText = await crypto.decryptTextMessage(receivedPayload, sharedKeyB);

      // Xác minh nội dung sau giải mã nguyên vẹn
      expect(decryptedText, equals(rawMessage));
    });

    test('4. Người A gọi activateSos -> Người B nhận và giải mã đúng lat, lng, senderName dù cả hai trùng displayName', () async {
      final aliceState = createTestAppState(crypto, storageA);
      final bobState = createTestAppState(crypto, storageB);

      const uidA = 'uid_A_tung_1';
      const uidB = 'uid_B_tung_2';
      const sameDisplayName = 'Tùng Phạm Văn';

      await aliceState.signInWithTestAccount(
        uid: uidA,
        email: 'phamtunghn11@gmail.com',
        displayName: sameDisplayName,
      );

      await bobState.signInWithTestAccount(
        uid: uidB,
        email: 'phamvantunghn2b@gmail.com',
        displayName: sameDisplayName,
      );

      // Thêm thành viên vào danh bạ gia đình dựa trên Firebase UID thật
      aliceState.addFamilyMember(
        name: sameDisplayName,
        relation: 'Người thân',
        email: 'phamvantunghn2b@gmail.com',
        uid: uidB,
        status: MemberConnectionStatus.accepted,
      );

      bobState.addFamilyMember(
        name: sameDisplayName,
        relation: 'Người thân',
        email: 'phamtunghn11@gmail.com',
        uid: uidA,
        status: MemberConnectionStatus.accepted,
      );

      // Xác minh ID phòng chung theo sort UID
      expect(aliceState.getCircleRoomId(), equals('circle_uid_a_tung_1___uid_b_tung_2'));
      expect(bobState.getCircleRoomId(), equals('circle_uid_a_tung_1___uid_b_tung_2'));
      expect(aliceState.getCircleRoomId(), equals(bobState.getCircleRoomId()));

      // A kích hoạt SOS
      const double originLat = 21.028511;
      const double originLng = 105.854222;

      final eventA = await aliceState.activateSos(
        lat: originLat,
        lng: originLng,
        isMocked: false,
        senderName: sameDisplayName,
      );

      expect(aliceState.isSosActive, isTrue);
      final encryptedPayload = aliceState.lastEncryptedSos;
      expect(encryptedPayload, isNotNull);

      // Firestore doc mô phỏng
      final firestoreDoc = {
        'sosId': eventA.sosId,
        'encryptedEvent': encryptedPayload!.encryptedEvent,
        'encryptedLocation': encryptedPayload.encryptedLocation,
        'senderUid': uidA,
        'senderEmail': 'phamtunghn11@gmail.com',
        'senderName': sameDisplayName,
        'sessionKeyId': aliceState.getCircleRoomId(),
        'status': 'active',
      };

      // B lắng nghe doc và resolve session key
      final sessionKeyBob = await bobState.resolveSosSessionKey(
        senderEmail: firestoreDoc['senderEmail'] as String,
        sessionKeyId: firestoreDoc['sessionKeyId'] as String,
      );

      final decryptedEvent = await bobState.receiveIncomingSos(
        encryptedEventBase64: firestoreDoc['encryptedEvent'] as String,
        encryptedLocationBase64: firestoreDoc['encryptedLocation'] as String,
        key: sessionKeyBob,
      );

      // Xác minh B giải mã thành công tọa độ và thông tin người phát SOS
      expect(decryptedEvent, isNotNull);
      expect(decryptedEvent!.lat, equals(originLat));
      expect(decryptedEvent.lng, equals(originLng));
      expect(decryptedEvent.senderName, equals(sameDisplayName));
      expect(bobState.isSosActive, isTrue);
      expect(bobState.isMySos, isFalse);
      expect(bobState.activeSos?.sosId, equals(eventA.sosId));
    });
  });
}
