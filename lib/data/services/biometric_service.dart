import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/secure_storage_service.dart';

/// Kết quả của một lần xác thực sinh trắc học.
enum BiometricResult {
  /// Xác thực thành công.
  success,

  /// Người dùng hủy (bấm Hủy / dùng back).
  cancelled,

  /// Thiết bị không có sinh trắc học hoặc chưa đăng ký, cần dùng mã PIN fallback.
  unavailableNeedsPin,

  /// Thiết bị gặp lỗi phần cứng tạm thời.
  unavailable,

  /// Lỗi khác (khóa tạm thời, quá nhiều lần thất bại, lỗi hệ thống...).
  failed,
}

/// Dịch vụ quản lý xác thực sinh trắc học cho các **vùng dữ liệu nhạy cảm**.
///
/// Theo nguyên tắc *Emergency Bypass*, service này **không** bảo vệ Bản đồ hay
/// nút SOS — nó chỉ được gọi khi người dùng truy cập gia đình, tin nhắn hoặc
/// nhật ký di chuyển.
///
/// Trạng thái mở khoá được duy trì an toàn trong **7 ngày (1 tuần)**: sau một lần
/// quét thành công, người dùng không bị hỏi lại liên tục. Khoá lại khi:
///  - phiên mở khóa quá [sessionTimeout] (7 ngày), hoặc
///  - người dùng đăng xuất / chủ động khoá (`lock()`).
class BiometricService extends ChangeNotifier {
  BiometricService({
    LocalAuthentication? localAuthentication,
    SecureStorageService? secureStorage,
    CryptoService? cryptoService,
  })  : _localAuth = localAuthentication ?? LocalAuthentication(),
        _storage = secureStorage ?? SecureStorageService(),
        _crypto = cryptoService ?? CryptoService() {
    _initPersistedSession();
  }

  final LocalAuthentication _localAuth;
  final SecureStorageService _storage;
  final CryptoService _crypto;

  /// Thời gian tối đa duy trì trạng thái "đã mở khoá" (1 tuần = 7 ngày).
  static const Duration sessionTimeout = Duration(days: 7);

  bool _unlockedThisSession = false;
  DateTime? _lastAuthenticatedAt;

  Future<void> _initPersistedSession() async {
    try {
      final last = await _storage.getLastBiometricAuthTime();
      if (last != null) {
        if (DateTime.now().difference(last) < sessionTimeout) {
          _unlockedThisSession = true;
          _lastAuthenticatedAt = last;
          notifyListeners();
        } else {
          await _storage.clearLastBiometricAuthTime();
        }
      }
    } catch (e) {
      debugPrint('[BiometricService] initPersistedSession skipped: $e');
    }
  }

  /// Người dùng đã xác thực thành công và còn trong thời hạn 7 ngày.
  bool get isUnlockedThisSession {
    if (!_unlockedThisSession) return false;
    final last = _lastAuthenticatedAt;
    if (last == null) return false;
    if (DateTime.now().difference(last) >= sessionTimeout) {
      _unlockedThisSession = false;
      return false;
    }
    return true;
  }

  /// Thời điểm xác thực thành công gần nhất.
  DateTime? get lastAuthenticatedAt => _lastAuthenticatedAt;

  /// Thiết bị có hỗ trợ sinh trắc học (vân tay / khuôn mặt) hay không.
  Future<bool> canAuthenticate() async {
    try {
      if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
        return false;
      }
      if (!await _localAuth.isDeviceSupported()) return false;
      if (!await _localAuth.canCheckBiometrics) return false;
      final List<BiometricType> enrolled =
          await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Kiểm tra xem người dùng đã đăng ký mã PIN fallback trong SecureStorage hay chưa.
  Future<bool> hasRegisteredPin() async {
    try {
      final stored = await _storage.getPinHash();
      return stored != null && stored.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Đăng ký mã PIN mới (yêu cầu đúng 6 chữ số).
  ///
  /// Sinh salt 16-byte từ Random.secure() và tính SHA-256(salt + pin) bằng CryptoService.
  /// Lưu vào key `pin_hash_v1` trong SecureStorage.
  Future<void> registerPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('Mã PIN phải gồm đúng 6 chữ số');
    }
    final rnd = Random.secure();
    final saltBytes = Uint8List.fromList(List<int>.generate(16, (_) => rnd.nextInt(256)));
    final saltHex = saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final hashObj = await _crypto.sha256Hash('$saltHex$pin');
    final hashHex = hashObj.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _storage.savePinHash('$saltHex:$hashHex');

    final now = DateTime.now();
    _unlockedThisSession = true;
    _lastAuthenticatedAt = now;
    try {
      await _storage.saveLastBiometricAuthTime(now);
    } catch (_) {}
    notifyListeners();
  }

  /// Xác minh mã PIN đã đăng ký.
  Future<bool> verifyPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      return false;
    }
    final stored = await _storage.getPinHash();
    if (stored == null || !stored.contains(':')) {
      return false;
    }
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final saltHex = parts[0];
    final expectedHashHex = parts[1];

    final hashObj = await _crypto.sha256Hash('$saltHex$pin');
    final calculatedHashHex = hashObj.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    if (calculatedHashHex == expectedHashHex) {
      final now = DateTime.now();
      _unlockedThisSession = true;
      _lastAuthenticatedAt = now;
      try {
        await _storage.saveLastBiometricAuthTime(now);
      } catch (_) {}
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Xác thực sinh trắc học để truy cập vùng dữ liệu nhạy cảm.
  ///
  /// Nếu phiên đã được mở khoá ([isUnlockedThisSession]) thì trả về
  /// [BiometricResult.success] ngay mà không hiện popup.
  ///
  /// [localizedReason] là thông điệp hiển thị trên popup của hệ điều hành.
  Future<BiometricResult> authenticateSensitiveAccess({
    required String localizedReason,
  }) async {
    // Đã mở khoá trong phiên → không hỏi lại.
    if (_unlockedThisSession) return BiometricResult.success;

    if (!await canAuthenticate()) {
      // Không có sinh trắc học → chuyển sang luồng mã PIN fallback
      return BiometricResult.unavailableNeedsPin;
    }

    try {
      final bool ok = await _localAuth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
      );
      if (ok) {
        final now = DateTime.now();
        _unlockedThisSession = true;
        _lastAuthenticatedAt = now;
        try {
          await _storage.saveLastBiometricAuthTime(now);
        } catch (_) {}
        notifyListeners();
        return BiometricResult.success;
      }
      return BiometricResult.cancelled;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.userRequestedFallback:
          return BiometricResult.cancelled;
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
          return BiometricResult.unavailableNeedsPin;
        default:
          return BiometricResult.failed;
      }
    } catch (_) {
      return BiometricResult.failed;
    }
  }

  /// Khoá thủ công — lần truy cập nhạy cảm kế tiếp sẽ phải xác thực lại.
  Future<void> lock() async {
    _unlockedThisSession = false;
    _lastAuthenticatedAt = null;
    try {
      await _storage.clearLastBiometricAuthTime();
    } catch (_) {}
    notifyListeners();
  }

  /// Gọi khi ứng dụng chuyển sang background.
  ///
  /// Nếu ứng dụng ở background quá [sessionTimeout] thì khoá lại, buộc người
  /// dùng phải xác thực cho lần truy cập nhạy cảm kế tiếp.
  void onBackgrounded() {
    final DateTime? last = _lastAuthenticatedAt;
    if (last == null) return;
    if (DateTime.now().difference(last) > sessionTimeout) {
      lock();
    }
  }

  /// Reset toàn bộ trạng thái (dùng cho test).
  @visibleForTesting
  void reset() {
    _unlockedThisSession = false;
    _lastAuthenticatedAt = null;
    notifyListeners();
  }

  /// Cài đặt trạng thái phiên (dùng cho test — không gọi popup thật).
  @visibleForTesting
  void setUnlockedForTesting(bool unlocked) {
    _unlockedThisSession = unlocked;
    _lastAuthenticatedAt = unlocked ? DateTime.now() : null;
    notifyListeners();
  }
}
