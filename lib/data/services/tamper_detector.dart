import 'package:geolocator/geolocator.dart';
import 'package:sos_safe_family/data/services/native_security_service.dart';

/// Kết quả kiểm tra toàn vẹn thiết bị.
class TamperReport {
  const TamperReport({
    required this.isRooted,
    required this.isMockLocation,
    required this.isScreenCaptureProtected,
  });

  /// Thiết bị đã root hay chưa.
  final bool isRooted;

  /// GPS hiện tại có phải vị trí giả lập (mock) hay không.
  final bool isMockLocation;

  /// Cờ `FLAG_SECURE` đang bật (chống chụp/quay màn hình).
  final bool isScreenCaptureProtected;

  /// Thiết bị có đáng tin cậy hay không.
  ///
  /// Chỉ bị coi là không đáng tin khi phát hiện root hoặc GPS giả lập.
  bool get isTrusted => !isRooted && !isMockLocation;

  /// Tóm tắt ngắn gọn để hiển thị trên UI.
  String get rootLabel =>
      isRooted ? 'Phát hiện Root' : 'An toàn (Không phát hiện)';
  String get gpsLabel => isMockLocation
      ? 'Phát hiện GPS giả lập'
      : 'GPS thực tế (Không phát hiện giả lập)';
  String get screenCaptureLabel => isScreenCaptureProtected
      ? 'Đang bảo vệ (FLAG_SECURE)'
      : 'Chưa bảo vệ (FLAG_SECURE tắt)';
}

/// Phát hiện các dấu hiệu can thiệp: root, GPS giả lập và trạng thái chống
/// chụp màn hình.
class TamperDetector {
  TamperDetector({NativeSecurityService? nativeService})
      : _native = nativeService ?? const NativeSecurityService();

  final NativeSecurityService _native;

  /// Vị trí GPS hiện tại có phải mock hay không.
  ///
  /// `Position.isMocked` do Android cung cấp — bật khi ứng dụng giả lập vị trí
  /// qua Developer Options hoặc app giả định vị.
  bool isMockLocation(Position position) {
    return position.isMocked;
  }

  /// Kiểm tra thiết bị đã root hay không (gọi xuống native).
  Future<bool> checkRoot() async {
    return _native.checkDeviceIntegrity();
  }

  /// Bật/tắt chống chụp màn hình (native `FLAG_SECURE`).
  Future<bool> setFlagSecure(bool enabled) async {
    return _native.setFlagSecure(enabled);
  }

  /// Thu thập toàn bộ trạng thái toàn vẹn thiết bị.
  ///
  /// [position] có thể là `null` nếu chưa có GPS — khi đó phần GPS được coi là
  /// an toàn (chưa có bằng chứng giả lập).
  Future<TamperReport> inspect({
    Position? position,
    bool screenCaptureProtected = true,
  }) async {
    final bool rooted = await checkRoot();
    final bool mocked = position != null && isMockLocation(position);

    return TamperReport(
      isRooted: rooted,
      isMockLocation: mocked,
      isScreenCaptureProtected: screenCaptureProtected,
    );
  }
}
