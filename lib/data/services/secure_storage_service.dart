import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dịch vụ lưu trữ an toàn bọc ngoài `FlutterSecureStorage`.
///
/// Trên Android, cấu hình `encryptedSharedPreferences: true` sử dụng
/// MasterKey lưu trong Android Keystore (TEE / StrongBox) để mã hóa dữ liệu.
class SecureStorageService {
  static const _androidOptions = AndroidOptions(
    resetOnError: true,
  );

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? _defaultStorage;

  // ---------------------------------------------------------------------------
  // Khóa cá nhân & Khóa công khai X25519 theo từng UID người dùng
  // ---------------------------------------------------------------------------

  /// Lưu Private Key X25519 (base64) vào Android Keystore theo UID.
  Future<void> saveUserPrivateKey(String uid, String privateKeyBase64) async {
    await _storage.write(key: 'x25519_priv_$uid', value: privateKeyBase64);
  }

  /// Đọc Private Key X25519 (base64) từ Android Keystore theo UID.
  Future<String?> getUserPrivateKey(String uid) async {
    return _storage.read(key: 'x25519_priv_$uid');
  }

  /// Lưu Public Key X25519 (base64) vào Secure Storage theo UID.
  Future<void> saveUserPublicKey(String uid, String publicKeyBase64) async {
    await _storage.write(key: 'x25519_pub_$uid', value: publicKeyBase64);
  }

  /// Đọc Public Key X25519 (base64) từ Secure Storage theo UID.
  Future<String?> getUserPublicKey(String uid) async {
    return _storage.read(key: 'x25519_pub_$uid');
  }

  /// Xóa sạch khóa X25519 của người dùng khi đăng xuất hoặc thu hồi.
  Future<void> deleteUserKeys(String uid) async {
    await _storage.delete(key: 'x25519_priv_$uid');
    await _storage.delete(key: 'x25519_pub_$uid');
  }

  // ---------------------------------------------------------------------------
  // Khóa chung & Mã PIN (cho các module hiện có)
  // ---------------------------------------------------------------------------

  Future<void> savePrivateKey(String privateKeyBase64) async {
    await _storage.write(key: 'private_key', value: privateKeyBase64);
  }

  Future<String?> getPrivateKey() async {
    return _storage.read(key: 'private_key');
  }

  Future<void> savePin(String pin) async {
    await _storage.write(key: 'pin', value: pin);
  }

  Future<String?> getPin() async {
    return _storage.read(key: 'pin');
  }

  // ---------------------------------------------------------------------------
  // Thời gian xác thực sinh trắc học gần nhất (Session TTL 7 ngày)
  // ---------------------------------------------------------------------------

  Future<void> saveLastBiometricAuthTime(DateTime time) async {
    try {
      await _storage.write(
        key: 'last_biometric_auth_time',
        value: time.toIso8601String(),
      );
    } catch (_) {}
  }

  Future<DateTime?> getLastBiometricAuthTime() async {
    try {
      final str = await _storage.read(key: 'last_biometric_auth_time');
      if (str == null || str.isEmpty) return null;
      return DateTime.tryParse(str);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLastBiometricAuthTime() async {
    try {
      await _storage.delete(key: 'last_biometric_auth_time');
    } catch (_) {}
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
