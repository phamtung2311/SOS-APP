import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/services/auth_service.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/location_share_service.dart';
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

AppState createTestAppState(CryptoService crypto) {
  final fakeStorage = FakeSecureStorageService();
  final authService = AuthService(
    cryptoService: crypto,
    secureStorage: fakeStorage,
  );
  return AppState(
    cryptoService: crypto,
    authService: authService,
  );
}

void main() {
  group('M17 Cross-Device Key Synchronization & SOS/Location Decryption Tests', () {
    late CryptoService crypto;
    late LocationShareService locationService;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      crypto = CryptoService();
      locationService = LocationShareService();
    });

    test('1. Hai máy trong cùng vòng tròn tự tính ra circleRoomId và khóa phiên đối xứng giống hệt nhau', () async {
      final aliceState = createTestAppState(crypto);
      final bobState = createTestAppState(crypto);

      await aliceState.signInWithTestAccount(
        email: 'tung.ct070161@kma.edu.vn',
        displayName: 'Phạm Văn Tùng',
      );
      await bobState.signInWithTestAccount(
        email: 'vu.ct070165@kma.edu.vn',
        displayName: 'Phạm Nguyên Vũ',
      );

      // Kết nối hai máy vào cùng vòng tròn gia đình bằng UID thật
      aliceState.addFamilyMember(
        name: 'Phạm Nguyên Vũ',
        relation: 'Người thân',
        email: 'vu.ct070165@kma.edu.vn',
        uid: bobState.currentUserUid,
        status: MemberConnectionStatus.accepted,
      );
      bobState.addFamilyMember(
        name: 'Phạm Văn Tùng',
        relation: 'Người thân',
        email: 'tung.ct070161@kma.edu.vn',
        uid: aliceState.currentUserUid,
        status: MemberConnectionStatus.accepted,
      );

      final circleA = aliceState.getCircleRoomId();
      final circleB = bobState.getCircleRoomId();

      // Xác minh ID phòng thống nhất dựa trên sort alphabet UID
      expect(circleA, equals(circleB));
      expect(circleA, equals('circle_test_uid_tung_ct070161_kma_edu_vn___test_uid_vu_ct070165_kma_edu_vn'));

      // Xác minh hai máy dẫn xuất cùng một khóa đối xứng AES-256
      final keyA = await aliceState.resolveSosSessionKey();
      final keyB = await bobState.resolveSosSessionKey();
      expect(keyA, equals(keyB));
      expect(keyA.length, equals(32));
    });

    test('2. Máy A gửi SOS -> Máy B giải mã thành công tọa độ GPS và tên người gửi không bị skip', () async {
      final aliceState = createTestAppState(crypto);
      final bobState = createTestAppState(crypto);

      await aliceState.signInWithTestAccount(
        email: 'tung.ct070161@kma.edu.vn',
        displayName: 'Phạm Văn Tùng',
      );
      await bobState.signInWithTestAccount(
        email: 'vu.ct070165@kma.edu.vn',
        displayName: 'Phạm Nguyên Vũ',
      );

      aliceState.addFamilyMember(
        name: 'Phạm Nguyên Vũ',
        relation: 'Người thân',
        email: 'vu.ct070165@kma.edu.vn',
        uid: bobState.currentUserUid,
        status: MemberConnectionStatus.accepted,
      );
      bobState.addFamilyMember(
        name: 'Phạm Văn Tùng',
        relation: 'Người thân',
        email: 'tung.ct070161@kma.edu.vn',
        uid: aliceState.currentUserUid,
        status: MemberConnectionStatus.accepted,
      );

      // Máy A kích hoạt SOS
      const double originLat = 21.028511;
      const double originLng = 105.854222;
      const String originSender = 'Phạm Văn Tùng';

      final eventA = await aliceState.activateSos(
        lat: originLat,
        lng: originLng,
        isMocked: false,
        senderName: originSender,
      );
      expect(aliceState.isSosActive, isTrue);

      final encryptedPayload = aliceState.lastEncryptedSos;
      expect(encryptedPayload, isNotNull);

      // Mô phỏng Document được lưu lên Firestore `sos_events/{id}`
      final firestoreDoc = {
        'sosId': eventA.sosId,
        'encryptedEvent': encryptedPayload!.encryptedEvent,
        'encryptedLocation': encryptedPayload.encryptedLocation,
        'senderUid': aliceState.currentUserUid,
        'senderEmail': 'tung.ct070161@kma.edu.vn',
        'senderName': originSender,
        'sessionKeyId': aliceState.getCircleRoomId(),
        'status': 'active',
      };

      // Máy B lắng nghe sự kiện SOS từ Firestore stream và giải mã
      final senderEmail = firestoreDoc['senderEmail'] as String;
      final sessionKeyId = firestoreDoc['sessionKeyId'] as String;

      final sessionKeyBob = await bobState.resolveSosSessionKey(
        senderEmail: senderEmail,
        sessionKeyId: sessionKeyId,
      );

      final decryptedEvent = await bobState.receiveIncomingSos(
        encryptedEventBase64: firestoreDoc['encryptedEvent'] as String,
        encryptedLocationBase64: firestoreDoc['encryptedLocation'] as String,
        key: sessionKeyBob,
      );

      // Xác minh Máy B giải mã thành công nguyên vẹn
      expect(decryptedEvent, isNotNull);
      expect(decryptedEvent!.lat, equals(originLat));
      expect(decryptedEvent.lng, equals(originLng));
      expect(decryptedEvent.senderName, equals(originSender));
      expect(bobState.isSosActive, isTrue);
      expect(bobState.isMySos, isFalse);
      expect(bobState.activeSos?.sosId, equals(eventA.sosId));
    });

    test('3. Đồng bộ vị trí thời gian thực (Location Sharing): Máy A mã hóa -> Máy B giải mã đúng tọa độ', () async {
      final aliceState = createTestAppState(crypto);
      final bobState = createTestAppState(crypto);

      await aliceState.signInWithTestAccount(
        email: 'tung.ct070161@kma.edu.vn',
        displayName: 'Phạm Văn Tùng',
      );
      await bobState.signInWithTestAccount(
        email: 'vu.ct070165@kma.edu.vn',
        displayName: 'Phạm Nguyên Vũ',
      );

      aliceState.addFamilyMember(
        name: 'Phạm Nguyên Vũ',
        relation: 'Người thân',
        email: 'vu.ct070165@kma.edu.vn',
        uid: bobState.currentUserUid,
        status: MemberConnectionStatus.accepted,
      );
      bobState.addFamilyMember(
        name: 'Phạm Văn Tùng',
        relation: 'Người thân',
        email: 'tung.ct070161@kma.edu.vn',
        uid: aliceState.currentUserUid,
        status: MemberConnectionStatus.accepted,
      );

      final circleRoomId = aliceState.getCircleRoomId();
      final keyBytes = await aliceState.resolveSosSessionKey(sessionKeyId: circleRoomId);

      // Máy A mã hóa tọa độ vị trí bằng encryptLocationPayload
      const double testLat = 20.9805;
      const double testLng = 105.7958;
      const int testBattery = 88;

      final encryptedPos = await crypto.encryptLocationPayload(
        lat: testLat,
        lng: testLng,
        key: SecretKey(keyBytes),
      );

      final locDoc = {
        'uid': aliceState.currentUserUid,
        'encryptedPos': encryptedPos,
        'isMocked': false,
        'battery': testBattery,
        'senderEmail': 'tung.ct070161@kma.edu.vn',
        'sessionKeyId': circleRoomId,
      };

      // Máy B nhận doc và giải mã
      final bobKeyBytes = await bobState.resolveSosSessionKey(
        senderEmail: locDoc['senderEmail'] as String,
        sessionKeyId: locDoc['sessionKeyId'] as String,
      );

      final decryptedLoc = await locationService.decryptLocationDoc(
        docData: locDoc,
        key: SecretKey(bobKeyBytes),
      );

      expect(decryptedLoc, isNotNull);
      expect(decryptedLoc.lat, equals(testLat));
      expect(decryptedLoc.lng, equals(testLng));
      expect(decryptedLoc.battery, equals(testBattery));
    });

    test('4. Đồng bộ sự kiện Geofence: Máy A phát sự kiện -> Máy B giải mã nguyên vẹn', () async {
      final aliceState = createTestAppState(crypto);
      final bobState = createTestAppState(crypto);

      await aliceState.signInWithTestAccount(
        email: 'tung.ct070161@kma.edu.vn',
        displayName: 'Phạm Văn Tùng',
      );
      await bobState.signInWithTestAccount(
        email: 'vu.ct070165@kma.edu.vn',
        displayName: 'Phạm Nguyên Vũ',
      );

      final circleRoomId = aliceState.getCircleRoomId(peerEmail: 'vu.ct070165@kma.edu.vn');
      final keyBytes = await aliceState.resolveSosSessionKey(sessionKeyId: circleRoomId);

      const fenceName = 'Học viện Kỹ thuật Mật mã';
      const action = 'enter';
      const lat = 20.9805;
      const lng = 105.7958;

      final encryptedEvent = await crypto.encryptLocationPayload(
        lat: lat,
        lng: lng,
        key: SecretKey(keyBytes),
      );

      final geoDoc = {
        'eventId': 'geo_12345',
        'uid': aliceState.currentUserUid,
        'senderUid': aliceState.currentUserUid,
        'senderName': 'Phạm Văn Tùng',
        'fenceName': fenceName,
        'action': action,
        'encryptedEvent': encryptedEvent,
        'senderEmail': 'tung.ct070161@kma.edu.vn',
        'sessionKeyId': circleRoomId,
      };

      // Máy B giải mã sự kiện Geofence
      final bobKeyBytes = await bobState.resolveSosSessionKey(
        senderEmail: geoDoc['senderEmail'] as String,
        sessionKeyId: geoDoc['sessionKeyId'] as String,
      );

      final decryptedGeo = await locationService.decryptGeofenceDoc(
        docData: geoDoc,
        key: SecretKey(bobKeyBytes),
      );

      expect(decryptedGeo, isNotNull);
      expect(decryptedGeo.fenceName, equals(fenceName));
      expect(decryptedGeo.isEnter, isTrue);
      expect(decryptedGeo.lat, equals(lat));
      expect(decryptedGeo.lng, equals(lng));
    });
  });
}
