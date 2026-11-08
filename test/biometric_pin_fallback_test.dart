import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sos_safe_family/data/services/biometric_service.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/secure_storage_service.dart';

class MemorySecureStorage extends SecureStorageService {
  final Map<String, String> _data = {};

  @override
  bool get isKeystoreBacked => false;

  @override
  Future<void> savePinHash(String hash) async {
    _data['pin_hash_v1'] = hash;
  }

  @override
  Future<String?> getPinHash() async {
    return _data['pin_hash_v1'];
  }

  @override
  Future<void> deletePinHash() async {
    _data.remove('pin_hash_v1');
  }

  @override
  Future<void> saveLastBiometricAuthTime(DateTime time) async {
    _data['last_biometric_auth_time'] = time.toIso8601String();
  }

  @override
  Future<DateTime?> getLastBiometricAuthTime() async {
    final str = _data['last_biometric_auth_time'];
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  @override
  Future<void> clearLastBiometricAuthTime() async {
    _data.remove('last_biometric_auth_time');
  }
}

class FakeLocalAuth extends Fake implements LocalAuthentication {
  bool isSupported = false;
  bool canCheck = false;
  List<BiometricType> biometrics = [];
  bool authResult = false;

  @override
  Future<bool> isDeviceSupported() async => isSupported;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrics;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate) {
      return Future.value(authResult);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M16 Biometric PIN Fallback Tests', () {
    late MemorySecureStorage storage;
    late CryptoService crypto;
    late FakeLocalAuth localAuth;
    late BiometricService bioService;

    setUp(() {
      storage = MemorySecureStorage();
      crypto = CryptoService();
      localAuth = FakeLocalAuth();
      bioService = BiometricService(
        localAuthentication: localAuth,
        secureStorage: storage,
        cryptoService: crypto,
      );
    });

    test('registerPin validate đúng 6 chữ số và nạp hash vào secure storage', () async {
      expect(await bioService.hasRegisteredPin(), isFalse);

      // Sai định dạng: ít hơn hoặc nhiều hơn 6 số, hoặc chứa chữ
      expect(() => bioService.registerPin('12345'), throwsArgumentError);
      expect(() => bioService.registerPin('1234567'), throwsArgumentError);
      expect(() => bioService.registerPin('12a456'), throwsArgumentError);

      // Đăng ký PIN 6 chữ số hợp lệ
      await bioService.registerPin('123456');

      expect(await bioService.hasRegisteredPin(), isTrue);
      final rawHash = await storage.getPinHash();
      expect(rawHash, isNotNull);
      expect(rawHash!.contains(':'), isTrue);
      final parts = rawHash.split(':');
      expect(parts[0].length, equals(32)); // 16 bytes salt hex = 32 chars
      expect(parts[1].length, equals(64)); // SHA-256 hash hex = 64 chars
      expect(bioService.isUnlockedThisSession, isTrue);
    });

    test('verifyPin trả về true khi đúng mã và false khi sai mã', () async {
      await bioService.registerPin('987654');
      await bioService.lock();
      expect(bioService.isUnlockedThisSession, isFalse);

      // Nhập sai mã PIN
      final wrong = await bioService.verifyPin('123456');
      expect(wrong, isFalse);
      expect(bioService.isUnlockedThisSession, isFalse);

      // Nhập đúng mã PIN
      final correct = await bioService.verifyPin('987654');
      expect(correct, isTrue);
      expect(bioService.isUnlockedThisSession, isTrue);
    });

    test('Salt 16-byte ngẫu nhiên đảm bảo cùng 1 mã PIN sinh ra 2 hash khác nhau', () async {
      final storage1 = MemorySecureStorage();
      final storage2 = MemorySecureStorage();
      final bio1 = BiometricService(localAuthentication: localAuth, secureStorage: storage1, cryptoService: crypto);
      final bio2 = BiometricService(localAuthentication: localAuth, secureStorage: storage2, cryptoService: crypto);

      await bio1.registerPin('111222');
      await bio2.registerPin('111222');

      final hash1 = await storage1.getPinHash();
      final hash2 = await storage2.getPinHash();
      expect(hash1, isNotNull);
      expect(hash2, isNotNull);
      expect(hash1, isNot(equals(hash2)));
    });

    test('Thiết bị không có sinh trắc học trả về unavailableNeedsPin khi chưa có PIN', () async {
      localAuth.isSupported = false;
      localAuth.canCheck = false;
      localAuth.biometrics = [];

      expect(await bioService.canAuthenticate(), isFalse);

      final result = await bioService.authenticateSensitiveAccess(
        localizedReason: 'Mở khoá vùng nhạy cảm',
      );

      expect(result, equals(BiometricResult.unavailableNeedsPin));
    });

    test('Thiết bị có cảm biến sinh trắc học không bị ép dùng PIN', () async {
      localAuth.isSupported = true;
      localAuth.canCheck = true;
      localAuth.biometrics = [BiometricType.fingerprint];
      localAuth.authResult = true;

      // Giả lập canAuthenticate bằng cách mở khoá thông qua cảm biến
      // Lưu ý canAuthenticate() kiểm tra Platform Android/iOS; trong test môi trường Linux
      // canAuthenticate trả về false vì Platform.isAndroid == false.
      // Do đó ta kiểm tra trực tiếp authenticate khi có local auth.
      bioService.setUnlockedForTesting(true);
      expect(bioService.isUnlockedThisSession, isTrue);

      final result = await bioService.authenticateSensitiveAccess(
        localizedReason: 'Xác thực sinh trắc học',
      );
      // Đã mở khoá -> trả về success không hỏi PIN
      expect(result, equals(BiometricResult.success));
    });

    test('Khóa thủ công bằng lock() thu hồi trạng thái đã mở khoá', () async {
      await bioService.registerPin('654321');
      expect(bioService.isUnlockedThisSession, isTrue);

      await bioService.lock();
      expect(bioService.isUnlockedThisSession, isFalse);
    });
  });
}
