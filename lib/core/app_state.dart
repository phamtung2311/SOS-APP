import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sos_safe_family/data/models/encrypted_sos_payload.dart';
import 'package:sos_safe_family/data/models/geofence.dart';
import 'package:sos_safe_family/data/models/sos_event.dart';
import 'package:sos_safe_family/data/services/auth_service.dart';
import 'package:sos_safe_family/data/services/biometric_service.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/geofence_service.dart';
import 'package:sos_safe_family/data/services/replay_guard.dart';
import 'package:sos_safe_family/data/services/sos_service.dart';
import 'package:sos_safe_family/data/services/tamper_detector.dart';
import 'package:uuid/uuid.dart';

/// Trạng thái ứng dụng dùng chung cho các màn hình.
///
/// Giữ vị trí GPS hiện tại, danh sách vùng an toàn, sự kiện SOS đang hoạt
/// động và nhật ký kiểm toán — nhờ đó nút SOS ở `MainScreen` và màn hình
/// `SecurityScreen` không phải truyền dữ liệu qua constructor.
class AppState extends ChangeNotifier {
  AppState({
    CryptoService? cryptoService,
    BiometricService? biometricService,
    TamperDetector? tamperDetector,
    AuthService? authService,
  })  : _crypto = cryptoService ?? CryptoService(),
        _biometric = biometricService ?? BiometricService(),
        _tamper = tamperDetector ?? TamperDetector(),
        _auth = authService ?? AuthService(cryptoService: cryptoService) {
    _sosService = SosService(cryptoService: _crypto);
    _geofences = GeofenceService.seedGeofences();
    _initAuthListener();
  }

  final CryptoService _crypto;
  final BiometricService _biometric;
  final TamperDetector _tamper;
  final AuthService _auth;
  StreamSubscription<UserSecurityProfile?>? _authSub;
  late final SosService _sosService;
  final Uuid _uuid = const Uuid();

  // ---- Tài khoản & Mật mã ----
  UserSecurityProfile? _userProfile;
  bool _isAuthLoading = false;

  void _initAuthListener() {
    try {
      _authSub = _auth.authStateChanges().listen((profile) {
        _userProfile = profile;
        notifyListeners();
      }, onError: (e) {
        debugPrint('[AppState] authStateChanges error: $e');
      });
    } catch (e) {
      debugPrint('[AppState] auth init skipped: $e');
    }
  }

  // ---- Vị trí ----
  Position? _lastPosition;
  LatLng? _currentLocation;
  bool _isMockGps = false;

  // ---- Geofence ----
  late List<Geofence> _geofences;
  final List<GeofenceTransition> _lastTransitions = [];

  // ---- SOS ----
  SosEvent? _activeSos;
  EncryptedSosPayload? _lastEncryptedSos;
  Uint8List? _sessionKey;

  // ---- Nhật ký kiểm toán ----
  final List<String> _auditLogs = <String>[];

  // ---- Bảo mật ----

  /// Bật khoá sinh trắc học cho các vùng dữ liệu nhạy cảm.
  ///
  /// Bản đồ & SOS luôn miễn nhiễm theo nguyên tắc Emergency Bypass.
  bool _sensitiveDataLockEnabled = true;

  /// Cờ chống chụp màn hình (`FLAG_SECURE` native).
  bool _flagSecureEnabled = true;

  /// Báo cáo toàn vẹn thiết bị (root / GPS giả / FLAG_SECURE).
  TamperReport? _tamperReport;

  // ---------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------

  UserSecurityProfile? get userProfile => _userProfile;
  bool get isSignedIn => _userProfile != null;
  bool get isAuthLoading => _isAuthLoading;
  AuthService get authService => _auth;

  Position? get lastPosition => _lastPosition;
  LatLng? get currentLocation => _currentLocation;
  bool get isMockGps => _isMockGps;
  List<Geofence> get geofences => List.unmodifiable(_geofences);
  List<GeofenceTransition> get lastTransitions => List.unmodifiable(_lastTransitions);
  SosEvent? get activeSos => _activeSos;
  bool get isSosActive => _activeSos?.isActive ?? false;
  EncryptedSosPayload? get lastEncryptedSos => _lastEncryptedSos;
  List<String> get auditLogs => List.unmodifiable(_auditLogs);

  // ---- Bảo mật getters ----

  /// Khoá sinh trắc học cho dữ liệu nhạy cảm đang bật hay không.
  bool get sensitiveDataLockEnabled => _sensitiveDataLockEnabled;

  /// Cờ chống chụp màn hình đang bật hay không.
  bool get flagSecureEnabled => _flagSecureEnabled;

  /// Dịch vụ sinh trắc học (được dùng bởi `BiometricGate`).
  BiometricService get biometricService => _biometric;

  /// Báo cáo toàn vẹn thiết bị hiện tại (có thể null nếu chưa kiểm tra).
  TamperReport? get tamperReport => _tamperReport;

  /// Mức pin hiện tại (%).
  ///
  /// Bản demo dùng giá trị mô phỏng; điểm tích hợp thật sẽ đọc từ
  /// `BatteryManager` qua plugin `battery_plus`.
  int get batteryLevel => _batteryLevel;

  /// Mức pin mô phỏng — điểm tích hợp thật sẽ đọc từ `BatteryManager`.
  static const int _batteryLevel = 87;

  // ---------------------------------------------------------------------
  // Vị trí
  // ---------------------------------------------------------------------

  /// Cập nhật vị trí mới nhất và đánh giá lại các vùng an toàn.
  void updatePosition(Position position) {
    _lastPosition = position;
    _isMockGps = position.isMocked;
    final LatLng loc = LatLng(position.latitude, position.longitude);
    _currentLocation = loc;

    _evaluateGeofences(loc);
    notifyListeners();
  }

  void _evaluateGeofences(LatLng position) {
    final transitions = GeofenceService.evaluateTransitions(
      currentPos: position,
      fences: _geofences,
    );
    _lastTransitions
      ..clear()
      ..addAll(transitions);

    if (transitions.isNotEmpty) {
      _geofences = GeofenceService.updateFenceStatuses(
        currentPos: position,
        fences: _geofences,
      );
      for (final t in transitions) {
        final String action = t.isEnter ? 'Đã vào vùng' : 'Đã rời vùng';
        addAuditLog('$action an toàn "${t.fence.name}"');
      }
    }
  }

  // ---------------------------------------------------------------------
  // Geofence
  // ---------------------------------------------------------------------

  /// Bật/tắt một vùng an toàn.
  void toggleGeofence(String id) {
    _geofences = _geofences.map((f) {
      if (f.id != id) return f;
      return f.copyWith(isEnabled: !f.isEnabled);
    }).toList();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // SOS
  // ---------------------------------------------------------------------

  /// Bảo đảm có khóa phiên 32 byte (ECDH X25519 tự thỏa thuận trong demo).
  Future<Uint8List> _ensureSessionKey() async {
    final Uint8List? existing = _sessionKey;
    if (existing != null) return existing;

    final alice = await _crypto.generateKeyPairX25519();
    final bob = await _crypto.generateKeyPairX25519();
    final shared = await _crypto.deriveSharedKey(
      myKeyPair: alice,
      theirPublicKey: await _crypto.importPublicKey(
        await _crypto.exportPublicKey(bob),
      ),
    );
    final Uint8List bytes = Uint8List.fromList(await shared.extractBytes());
    _sessionKey = bytes;
    return bytes;
  }

  /// Kích hoạt sự kiện SOS khẩn cấp.
  ///
  /// Đóng gói payload, mã hóa AES-256-GCM và chuyển ứng dụng sang trạng
  /// thái khẩn cấp đang bật.
  Future<SosEvent> activateSos({
    required double lat,
    required double lng,
    required bool isMocked,
    required String senderName,
  }) async {
    final event = SosEvent(
      sosId: _uuid.v4(),
      senderName: senderName,
      lat: lat,
      lng: lng,
      isMocked: isMocked,
      batteryLevel: batteryLevel,
      timestamp: DateTime.now(),
      status: SosStatus.active,
    );

    final key = await _ensureSessionKey();
    final encrypted = await _sosService.encryptEvent(event: event, key: key);

    _activeSos = event;
    _lastEncryptedSos = encrypted;

    final String hhmm = DateTime.now().toIso8601String().substring(11, 16);
    addAuditLog(
      '$hhmm - Bạn đã kích hoạt cảnh báo SOS (Đã mã hóa E2EE)',
    );

    notifyListeners();
    return event;
  }

  /// Nhận một gói tin SOS đến từ máy chủ và kích hoạt cảnh báo khẩn cấp.
  ///
  /// Trước khi kích hoạt, gói tin được [SosService.receiveSos] kiểm tra:
  ///  * **Replay** (nonce trùng hoặc quá hạn) → ghi cảnh báo tấn công vào
  ///    [auditLogs] và **không** kích hoạt cảnh báo.
  ///  * **Can thiệp dữ liệu** (MAC sai) → tương tự, ghi log và từ chối.
  ///
  /// Trả về sự kiện SOS đã kích hoạt, hoặc `null` nếu gói tin bị từ chối.
  Future<SosEvent?> receiveIncomingSos({
    required String encryptedEventBase64,
    required String encryptedLocationBase64,
    required Uint8List key,
  }) async {
    try {
      final SosEvent event = await _sosService.handleIncomingSos(
        encryptedPayload: EncryptedSosPayload(
          event: SosEvent.fromJson(const <String, dynamic>{}),
          encryptedEvent: encryptedEventBase64,
          encryptedLocation: encryptedLocationBase64,
        ),
        sharedKey: SecretKey(key),
      );

      _activeSos = event;
      final String hhmm = DateTime.now().toIso8601String().substring(11, 16);
      addAuditLog(
        '$hhmm - Nhận cảnh báo SOS hợp lệ từ "${event.senderName}" '
        '(đã giải mã E2EE)',
      );
      notifyListeners();
      return event;
    } on ReplayAttackException catch (e) {
      final String hhmm = DateTime.now().toIso8601String().substring(11, 16);
      final String reason = switch (e.verdict) {
        ReplayVerdict.expired => 'gói tin quá hạn',
        ReplayVerdict.duplicateNonce => 'nonce trùng (gói tin bị phát lại)',
        ReplayVerdict.accepted => 'không xác định',
      };
      addAuditLog(
        '$hhmm - CẢNH BÁO TẤN CÔNG: từ chối gói tin SOS bị phát lại ($reason)',
      );
      notifyListeners();
      return null;
    } on SecretBoxAuthenticationError {
      final String hhmm = DateTime.now().toIso8601String().substring(11, 16);
      addAuditLog(
        '$hhmm - CẢNH BÁO TẤN CÔNG: từ chối gói tin SOS bị can thiệp dữ liệu '
        '(MAC không khớp)',
      );
      notifyListeners();
      return null;
    }
  }

  /// Người dùng xác nhận an toàn → chuyển sự kiện `ACTIVE` → `RESOLVED`.
  void resolveSos() {
    final SosEvent? current = _activeSos;
    if (current == null || current.isResolved) return;

    _activeSos = current.resolve();
    final String hhmm = DateTime.now().toIso8601String().substring(11, 16);
    addAuditLog('$hhmm - Bạn đã xác nhận an toàn (SOS đã kết thúc)');
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Nhật ký kiểm toán
  // ---------------------------------------------------------------------

  /// Ghi một dòng vào nhật ký kiểm toán (hiển thị ở `SecurityScreen`).
  void addAuditLog(String entry) {
    _auditLogs.insert(0, entry);
    if (_auditLogs.length > 50) {
      _auditLogs.removeLast();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Bảo mật & Toàn vẹn thiết bị
  // ---------------------------------------------------------------------

  /// Bật/tắt khoá sinh trắc học cho vùng dữ liệu nhạy cảm.
  void setSensitiveDataLock(bool enabled) {
    _sensitiveDataLockEnabled = enabled;
    notifyListeners();
  }

  /// Bật/tắt cờ chống chụp màn hình (gọi native FLAG_SECURE).
  Future<void> setFlagSecure(bool enabled) async {
    _flagSecureEnabled = enabled;
    await _tamper.setFlagSecure(enabled);
    await refreshTamperReport();
    notifyListeners();
  }

  /// Làm mới báo cáo toàn vẹn thiết bị (root, GPS giả lập, FLAG_SECURE).
  Future<TamperReport> refreshTamperReport() async {
    final report = await _tamper.inspect(
      position: _lastPosition,
      screenCaptureProtected: _flagSecureEnabled,
    );
    _tamperReport = report;
    notifyListeners();
    return report;
  }
  /// Đăng nhập bằng Google + Tự động sinh/nạp cặp khóa X25519 Keystore.
  Future<bool> signInWithGoogle() async {
    _isAuthLoading = true;
    notifyListeners();
    try {
      final profile = await _auth.signInWithGoogle();
      if (profile != null) {
        _userProfile = profile;
        _auditLogs.insert(
          0,
          '[XÁC THỰC] Đăng nhập Google: ${profile.email} • Khóa X25519 Keystore: ${profile.publicKeyFingerprint}',
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _auditLogs.insert(0, '[CẢNH BÁO] Đăng nhập Google thất bại: $e');
      rethrow;
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  /// Đăng xuất tài khoản người dùng.
  Future<void> signOut() async {
    final email = _userProfile?.email ?? 'Người dùng';
    await _auth.signOut();
    _userProfile = null;
    _auditLogs.insert(0, '[XÁC THỰC] Đã đăng xuất tài khoản: $email');
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

/// Cung cấp [AppState] cho cây widget.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope không tìm thấy trong cây widget.');
    return scope!.notifier!;
  }

  /// Đọc [AppState] mà không đăng ký lắng nghe thay đổi.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope không tìm thấy trong cây widget.');
    return scope!.notifier!;
  }
}
