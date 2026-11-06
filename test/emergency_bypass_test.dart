import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/services/tamper_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Emergency Bypass Architecture & Scoped Gate', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    tearDown(() {
      appState.dispose();
    });

    test('Zero Barrier: Bản đồ & SOS luôn mở khẩn cấp mà không bị chặn',
        () async {
      // Mặc định tính năng khoá nhạy cảm bật
      expect(appState.sensitiveDataLockEnabled, isTrue);

      // Trạng thái SOS ban đầu chưa kích hoạt
      expect(appState.isSosActive, isFalse);

      // Kích hoạt SOS thành công ngay lập tức không cần sinh trắc học
      await appState.activateSos(
        senderName: 'Phạm Văn Tùng',
        lat: 21.0285,
        lng: 105.8542,
        isMocked: false,
      );
      expect(appState.isSosActive, isTrue);
      expect(appState.activeSos, isNotNull);

      // Huỷ trạng thái khẩn cấp cũng không bị chặn
      appState.resolveSos();
      expect(appState.isSosActive, isFalse);
    });

    test('Scoped Gate: Cho phép bật/tắt khoá nhạy cảm và cờ FLAG_SECURE',
        () async {
      expect(appState.sensitiveDataLockEnabled, isTrue);
      appState.setSensitiveDataLock(false);
      expect(appState.sensitiveDataLockEnabled, isFalse);

      appState.setSensitiveDataLock(true);
      expect(appState.sensitiveDataLockEnabled, isTrue);

      expect(appState.flagSecureEnabled, isTrue);
      await appState.setFlagSecure(false);
      expect(appState.flagSecureEnabled, isFalse);
    });

    test('BiometricService: Quản lý phiên mở khoá (session-based unlock)', () {
      final bio = appState.biometricService;

      // Ban đầu chưa mở khoá trong phiên
      expect(bio.isUnlockedThisSession, isFalse);
      expect(bio.lastAuthenticatedAt, isNull);

      // Giả lập mở khoá thành công
      bio.setUnlockedForTesting(true);
      expect(bio.isUnlockedThisSession, isTrue);
      expect(bio.lastAuthenticatedAt, isNotNull);

      // Khoá chủ động
      bio.lock();
      expect(bio.isUnlockedThisSession, isFalse);
      expect(bio.lastAuthenticatedAt, isNull);
    });

    test('BiometricService: Tự động khoá lại sau sessionTimeout khi background',
        () {
      final bio = appState.biometricService;
      bio.setUnlockedForTesting(true);
      expect(bio.isUnlockedThisSession, isTrue);

      // Chưa vượt quá timeout thì vẫn giữ trạng thái mở khoá
      bio.onBackgrounded();
      expect(bio.isUnlockedThisSession, isTrue);
    });

    test('TamperReport: Đánh giá độ tin cậy thiết bị dựa trên Root & Mock GPS',
        () {
      const safeReport = TamperReport(
        isRooted: false,
        isMockLocation: false,
        isScreenCaptureProtected: true,
      );
      expect(safeReport.isTrusted, isTrue);
      expect(safeReport.rootLabel, contains('An toàn'));
      expect(safeReport.gpsLabel, contains('GPS thực tế'));
      expect(safeReport.screenCaptureLabel, contains('Đang bảo vệ'));

      const rootedReport = TamperReport(
        isRooted: true,
        isMockLocation: false,
        isScreenCaptureProtected: true,
      );
      expect(rootedReport.isTrusted, isFalse);
      expect(rootedReport.rootLabel, contains('Root'));

      const mockGpsReport = TamperReport(
        isRooted: false,
        isMockLocation: true,
        isScreenCaptureProtected: false,
      );
      expect(mockGpsReport.isTrusted, isFalse);
      expect(mockGpsReport.gpsLabel, contains('giả lập'));
    });
  });
}
