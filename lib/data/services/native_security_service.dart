import 'package:flutter/services.dart';

/// Cầu nối tới lớp bảo mật native Android (`MainActivity.kt`).
///
/// MethodChannel: `vn.atbm.sos/security`
///  - `setFlagSecure(enabled)`: bật/tắt `FLAG_SECURE` → chống chụp/quay màn hình.
///  - `checkDeviceIntegrity()`: phát hiện thiết bị đã root.
class NativeSecurityService {
  const NativeSecurityService();

  static const MethodChannel _channel = MethodChannel('vn.atbm.sos/security');

  /// Bật/tắt cờ `FLAG_SECURE` trên cửa sổ Activity.
  ///
  /// Trả về `true` nếu lệnh đã được gửi thành công. Trên nền tảng không hỗ trợ
  /// (ví dụ khi chạy test trên desktop) trả về `false` — cờ bảo mật chỉ có ý
  /// nghĩa trên Android thật.
  Future<bool> setFlagSecure(bool enabled) async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('setFlagSecure', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Kiểm tra thiết bị đã root hay chưa.
  ///
  /// Trả về `false` (không phát hiện root) nếu nền tảng không hỗ trợ.
  Future<bool> checkDeviceIntegrity() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('checkDeviceIntegrity');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
