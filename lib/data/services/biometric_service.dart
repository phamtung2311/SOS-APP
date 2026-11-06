import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Kết quả của một lần xác thực sinh trắc học.
enum BiometricResult {
  /// Xác thực thành công.
  success,

  /// Người dùng hủy (bấm Hủy / dùng back).
  cancelled,

  /// Thiết bị không có sinh trắc học hoặc chưa đăng ký.
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
/// Trạng thái mở khoá được quản lý theo phiên làm việc: sau một lần quét
/// thành công, người dùng không bị hỏi lại liên tục. Khoá lại khi:
///  - ứng dụng bị đưa vào background quá [sessionTimeout], hoặc
///  - người dùng chủ động khoá (`lock()`).
class BiometricService extends ChangeNotifier {
  BiometricService({LocalAuthentication? localAuthentication})
      : _localAuth = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  /// Thời gian tối đa được phép ở lại trạng thái "đã mở khoá" sau khi app bị
  /// đưa vào background.
  static const Duration sessionTimeout = Duration(minutes: 1);

  bool _unlockedThisSession = false;
  DateTime? _lastAuthenticatedAt;

  /// Người dùng đã xác thực thành công trong phiên làm việc hiện tại.
  bool get isUnlockedThisSession => _unlockedThisSession;

  /// Thời điểm xác thực thành công gần nhất.
  DateTime? get lastAuthenticatedAt => _lastAuthenticatedAt;

  /// Thiết bị có hỗ trợ sinh trắc học (vân tay / khuôn mặt) hay không.
  ///
  /// Trả về `false` trên nền tảng không hỗ trợ (ví dụ widget test) để ứng dụng
  /// không bị chặn vô ích.
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
      // Không có sinh trắc học: cho phép qua (thiết bị có thể dùng PIN,
      // và nguyên tắc "cứu hộ" quan trọng hơn việc chặn).
      return BiometricResult.unavailable;
    }

    try {
      final bool ok = await _localAuth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
      );
      if (ok) {
        _unlockedThisSession = true;
        _lastAuthenticatedAt = DateTime.now();
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
          return BiometricResult.unavailable;
        default:
          return BiometricResult.failed;
      }
    } catch (_) {
      return BiometricResult.failed;
    }
  }

  /// Khoá thủ công — lần truy cập nhạy cảm kế tiếp sẽ phải xác thực lại.
  void lock() {
    if (!_unlockedThisSession) return;
    _unlockedThisSession = false;
    _lastAuthenticatedAt = null;
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
