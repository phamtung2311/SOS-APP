import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/data/services/auth_service.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/secure_storage_service.dart';

/// Bộ lưu trữ giả lập trong bộ nhớ để kiểm thử Key Provisioning không cần thiết bị thật.
class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> _memory = {};

  @override
  bool get isKeystoreBacked => false;

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

void main() {
  group('M8 Key Provisioning & Android Keystore integration tests', () {
    late CryptoService cryptoService;
    late FakeSecureStorageService fakeStorage;
    late AuthService authService;

    setUp(() {
      cryptoService = CryptoService();
      fakeStorage = FakeSecureStorageService();
      authService = AuthService(
        cryptoService: cryptoService,
        secureStorage: fakeStorage,
      );
    });

    test('Tự động sinh cặp khóa X25519 và lưu vào Keystore khi lần đầu đăng nhập',
        () async {
      const uid = 'google_user_test_123';
      const displayName = 'Phạm Văn Tùng';
      const email = 'tung@example.com';

      // Ban đầu trong Keystore chưa có khóa
      expect(await fakeStorage.getUserPrivateKey(uid), isNull);
      expect(await fakeStorage.getUserPublicKey(uid), isNull);

      // Kích hoạt Provisioning
      final profile = await authService.provisionOrLoadUserKeys(
        uid: uid,
        displayName: displayName,
        email: email,
      );

      // Kiểm tra thông tin hồ sơ
      expect(profile.uid, equals(uid));
      expect(profile.displayName, equals(displayName));
      expect(profile.email, equals(email));
      expect(profile.isKeystoreProtected, isFalse);

      // Kiểm tra định dạng khóa X25519
      expect(profile.publicKeyB64, isNotEmpty);
      final pubBytes = base64Decode(profile.publicKeyB64);
      expect(pubBytes.length, equals(32)); // Chuẩn X25519 là 32 byte

      // Khóa private đã được lưu trong Keystore
      final savedPrivB64 = await fakeStorage.getUserPrivateKey(uid);
      expect(savedPrivB64, isNotNull);
      final privBytes = base64Decode(savedPrivB64!);
      expect(privBytes.length, equals(32));

      // Vân tay khóa công khai chuẩn 8 cụm hex (ví dụ: AA:BB:CC:DD:EE:FF:00:11)
      expect(profile.publicKeyFingerprint, matches(r'^([0-9A-F]{2}:){7}[0-9A-F]{2}$'));
    });

    test(
        'Tái sử dụng khóa X25519 đã có trong Keystore ở lần đăng nhập tiếp theo (Idempotent)',
        () async {
      const uid = 'google_user_returning_456';

      // Đăng nhập lần 1: sinh khóa mới
      final profile1 = await authService.provisionOrLoadUserKeys(
        uid: uid,
        displayName: 'Người Dùng Cũ',
        email: 'returning@example.com',
      );

      final firstPriv = await fakeStorage.getUserPrivateKey(uid);
      final firstPub = profile1.publicKeyB64;
      final firstFingerprint = profile1.publicKeyFingerprint;

      // Đăng nhập lần 2: nạp lại khóa từ Keystore
      final profile2 = await authService.provisionOrLoadUserKeys(
        uid: uid,
        displayName: 'Người Dùng Cũ (Đổi tên)',
        email: 'returning@example.com',
      );

      // Khóa và vân tay phải hoàn toàn trùng khớp với lần 1, không được sinh lại
      expect(profile2.publicKeyB64, equals(firstPub));
      expect(profile2.publicKeyFingerprint, equals(firstFingerprint));
      expect(await fakeStorage.getUserPrivateKey(uid), equals(firstPriv));
    });

    test('X25519 Key Agreement (ECDH) giữa 2 người dùng tạo ra cùng Shared Secret',
        () async {
      // User A (Alice)
      final profileA = await authService.provisionOrLoadUserKeys(
        uid: 'user_alice',
        displayName: 'Alice',
        email: 'alice@family.vn',
      );
      final privA = await fakeStorage.getUserPrivateKey('user_alice');
      final keyPairA = await cryptoService.importKeyPair(
        privateKeyB64: privA!,
        publicKeyB64: profileA.publicKeyB64,
      );

      // User B (Bob)
      final profileB = await authService.provisionOrLoadUserKeys(
        uid: 'user_bob',
        displayName: 'Bob',
        email: 'bob@family.vn',
      );
      final privB = await fakeStorage.getUserPrivateKey('user_bob');
      final keyPairB = await cryptoService.importKeyPair(
        privateKeyB64: privB!,
        publicKeyB64: profileB.publicKeyB64,
      );

      // Alice tính shared key với Bob's public key
      final bobPublicKey = await cryptoService.importPublicKey(profileB.publicKeyB64);
      final secretA = await cryptoService.deriveSharedKey(
        myKeyPair: keyPairA,
        theirPublicKey: bobPublicKey,
      );

      // Bob tính shared key với Alice's public key
      final alicePublicKey = await cryptoService.importPublicKey(profileA.publicKeyB64);
      final secretB = await cryptoService.deriveSharedKey(
        myKeyPair: keyPairB,
        theirPublicKey: alicePublicKey,
      );

      // Hai khóa bí mật dẫn xuất phải giống hệt nhau
      final bytesA = await secretA.extractBytes();
      final bytesB = await secretB.extractBytes();
      expect(bytesA, equals(bytesB));
    });

    test('Xóa khóa an toàn khi người dùng thu hồi tài khoản', () async {
      const uid = 'user_to_delete';
      await authService.provisionOrLoadUserKeys(
        uid: uid,
        displayName: 'Tạm thời',
        email: 'temp@family.vn',
      );

      expect(await fakeStorage.getUserPrivateKey(uid), isNotNull);
      expect(await fakeStorage.getUserPublicKey(uid), isNotNull);

      await fakeStorage.deleteUserKeys(uid);

      expect(await fakeStorage.getUserPrivateKey(uid), isNull);
      expect(await fakeStorage.getUserPublicKey(uid), isNull);
    });

    test('Default SecureStorageService is Keystore-backed', () {
      final realStorage = SecureStorageService();
      expect(realStorage.isKeystoreBacked, isTrue);
    });

    test('config mặc định trên Android phải có encryptedSharedPreferences: true', () {
      expect(SecureStorageService.androidOptions.encryptedSharedPreferences, isTrue);
      expect(SecureStorageService.androidOptions.aesGcmMasterKeys, contains('sos_master_key'));
    });
  });
}
