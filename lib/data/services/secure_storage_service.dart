import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const secureStorage = FlutterSecureStorage();

  Future<void> savePrivateKey(String privateKeyBase64) async {
    await secureStorage.write(key: 'private_key', value: privateKeyBase64);
  }

  Future<String?> getPrivateKey() async {
    return secureStorage.read(key: 'private_key');
  }

  Future<void> savePin(String pin) async {
    await secureStorage.write(key: 'pin', value: pin);
  }

  Future<String?> getPin() async {
    return secureStorage.read(key: 'pin');
  }

  Future<void> clearAll() async {
    await secureStorage.deleteAll();
  }
}
