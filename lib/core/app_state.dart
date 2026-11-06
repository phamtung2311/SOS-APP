import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sos_safe_family/data/models/geofence.dart';
import 'package:sos_safe_family/data/models/sos_event.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/geofence_service.dart';
import 'package:sos_safe_family/data/services/sos_service.dart';
import 'package:uuid/uuid.dart';

/// Trạng thái ứng dụng dùng chung cho các màn hình.
///
/// Giữ vị trí GPS hiện tại, danh sách vùng an toàn, sự kiện SOS đang hoạt
/// động và nhật ký kiểm toán — nhờ đó nút SOS ở `MainScreen` và màn hình
/// `SecurityScreen` không phải truyền dữ liệu qua constructor.
class AppState extends ChangeNotifier {
  AppState({CryptoService? cryptoService})
      : _crypto = cryptoService ?? CryptoService() {
    _sosService = SosService(cryptoService: _crypto);
    _geofences = GeofenceService.seedGeofences();
  }

  final CryptoService _crypto;
  late final SosService _sosService;
  final Uuid _uuid = const Uuid();

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

  // ---------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------

  Position? get lastPosition => _lastPosition;
  LatLng? get currentLocation => _currentLocation;
  bool get isMockGps => _isMockGps;
  List<Geofence> get geofences => List.unmodifiable(_geofences);
  List<GeofenceTransition> get lastTransitions => List.unmodifiable(_lastTransitions);
  SosEvent? get activeSos => _activeSos;
  bool get isSosActive => _activeSos?.isActive ?? false;
  EncryptedSosPayload? get lastEncryptedSos => _lastEncryptedSos;
  List<String> get auditLogs => List.unmodifiable(_auditLogs);

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
