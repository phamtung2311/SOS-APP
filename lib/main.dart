import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/models/geofence.dart';
import 'package:sos_safe_family/data/models/sos_event.dart';
import 'package:sos_safe_family/data/services/biometric_service.dart';
import 'package:sos_safe_family/data/services/geofence_service.dart';
import 'package:sos_safe_family/data/services/tamper_detector.dart';
import 'package:sos_safe_family/data/services/trip_share_service.dart';
import 'package:sos_safe_family/presentation/screens/family_chat_screen.dart';
import 'package:sos_safe_family/presentation/screens/sos_countdown_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[Firebase] Khởi tạo bỏ qua hoặc ngoại lệ: $e');
  }
  runApp(const SOSFamilyApp());
}

class SOSFamilyApp extends StatefulWidget {
  const SOSFamilyApp({super.key});

  @override
  State<SOSFamilyApp> createState() => _SOSFamilyAppState();
}

class _SOSFamilyAppState extends State<SOSFamilyApp> with WidgetsBindingObserver {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kích hoạt cờ chống chụp màn hình nếu được cấu hình mặc định
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_state.flagSecureEnabled) {
        _state.setFlagSecure(true);
      }
      _state.initForegroundTask();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _state.biometricService.onBackgrounded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'SOS An Toàn Gia Đình',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE53935),
            brightness: Brightness.light,
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

/// Hộp thoại nhập / đăng ký mã PIN dự phòng khi thiết bị không có cảm biến sinh trắc học.
Future<bool> _showPinFallbackDialog(
    BuildContext context, BiometricService biometricService) async {
  final hasPin = await biometricService.hasRegisteredPin();
  final pinController = TextEditingController();
  String? errorMessage;

  if (!context.mounted) return false;

  final bool? success = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Bảo mật'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPin
                      ? 'Nhập mã PIN 6 chữ số để xác thực mở khoá vùng riêng tư:'
                      : 'Thiết bị không hỗ trợ sinh trắc học. Vui lòng đăng ký mã PIN 6 chữ số để bảo vệ thông tin gia đình:',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Mã PIN (6 chữ số)',
                    errorText: errorMessage,
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pin = pinController.text.trim();
                  if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
                    setDialogState(() {
                      errorMessage = 'Mã PIN phải đúng 6 chữ số';
                    });
                    return;
                  }
                  if (!hasPin) {
                    try {
                      await biometricService.registerPin(pin);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (e) {
                      setDialogState(() {
                        errorMessage = 'Lỗi đăng ký PIN: $e';
                      });
                    }
                  } else {
                    final ok = await biometricService.verifyPin(pin);
                    if (ok) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } else {
                      setDialogState(() {
                        errorMessage = 'Mã PIN không đúng. Vui lòng thử lại';
                      });
                    }
                  }
                },
                child: Text(hasPin ? 'Xác nhận' : 'Đăng ký PIN lần đầu'),
              ),
            ],
          );
        },
      );
    },
  );

  return success ?? false;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Timer? _sosTimer;

  final List<Widget> _pages = const [
    MapScreen(),
    CircleScreen(),
    AuditLogScreen(),
    ProfileScreen(),
  ];

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required AppState appState,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFFE53935) : const Color(0xFF546E7A);
    return Expanded(
      child: InkWell(
        onTap: () => _handleNavTap(index, appState),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Điều hướng tab theo nguyên tắc Emergency Bypass:
  /// - Tab 0 (Bản đồ): Zero Barrier — mở ngay lập tức, không bao giờ hỏi mật khẩu/vân tay.
  /// - Tab 1, 2, 3: Vùng nhạy cảm — xác thực sinh trắc học nếu tính năng đang bật và chưa mở trong phiên.
  Future<void> _handleNavTap(int index, AppState appState) async {
    if (index == _selectedIndex) return;

    if (index == 0) {
      setState(() => _selectedIndex = 0);
      return;
    }

    if (appState.sensitiveDataLockEnabled &&
        !appState.biometricService.isUnlockedThisSession) {
      final BiometricResult result =
          await appState.biometricService.authenticateSensitiveAccess(
        localizedReason:
            'Xác thực vân tay/mật khẩu để mở vùng riêng tư gia đình',
      );
      if (result.name == 'unavailableNeedsPin') {
        if (!mounted) return;
        final ok =
            await _showPinFallbackDialog(context, appState.biometricService);
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Yêu cầu xác thực mã PIN để truy cập dữ liệu gia đình'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      } else if (result != BiometricResult.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yêu cầu xác thực để truy cập dữ liệu gia đình'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppScope.read(context),
      builder: (context, _) {
        final appState = AppScope.read(context);
        return Scaffold(
          body: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
              // Banner trạng thái khẩn cấp (nằm trên tất cả màn hình).
              if (appState.isSosActive)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _SosEmergencyBanner(
                    appState: appState,
                    onOpenMap: () {
                      _handleNavTap(0, appState);
                      final active = appState.activeSos;
                      if (active != null) {
                        appState.focusLocation(LatLng(active.lat, active.lng));
                      }
                    },
                  ),
                ),
            ],
          ),
          floatingActionButton: _buildSosFab(context, appState),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            color: Colors.white,
            elevation: 8,
            padding: EdgeInsets.zero,
            height: 64,
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  label: 'Bản đồ',
                  appState: appState,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.groups_outlined,
                  activeIcon: Icons.groups,
                  label: 'Vòng tròn',
                  appState: appState,
                ),
                const SizedBox(width: 76),
                _buildNavItem(
                  index: 2,
                  icon: Icons.history_rounded,
                  activeIcon: Icons.history,
                  label: 'Nhật ký',
                  appState: appState,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Cá nhân',
                  appState: appState,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Nút SOS: giữ 2 giây → đếm ngược 3 giây → kích hoạt khẩn cấp.
  Widget _buildSosFab(BuildContext context, AppState appState) {
    if (appState.isSosActive) {
      return Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFB71C1C),
          boxShadow: [
            BoxShadow(color: const Color(0x66B71C1C), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: const Icon(Icons.sos, color: Colors.white, size: 32),
      );
    }

    return GestureDetector(
      onLongPressStart: (_) {
        _sosTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            _showSosCountdown(appState);
          }
        });
      },
      onLongPressEnd: (_) {
        _sosTimer?.cancel();
        _sosTimer = null;
      },
      onLongPressCancel: () {
        _sosTimer?.cancel();
        _sosTimer = null;
      },
      child: Container(
        width: 74,
        height: 74,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFF4D4F), Color(0xFFB71C1C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(color: Color(0x66E53935), blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        child: const Icon(Icons.sos, color: Colors.white, size: 32),
      ),
    );
  }

  /// Mở màn hình đếm ngược SOS 3 giây.
  ///
  /// Nguyên tắc "an toàn trước tiên": cảnh báo **luôn** được kích hoạt, kể cả
  /// khi chưa có toạ độ GPS — dùng toạ độ cuối cùng nếu có, nếu không thì dùng
  /// tâm bản đồ mặc định và đánh dấu `isMocked = true` để gia đình biết đây
  /// không phải vị trí GPS thực.
  void _showSosCountdown(AppState appState) async {
    final Position? position = appState.lastPosition;
    final LatLng fallback =
        appState.currentLocation ?? const LatLng(21.0285, 105.8542);
    final double lat = position?.latitude ?? fallback.latitude;
    final double lng = position?.longitude ?? fallback.longitude;
    final bool mocked = position == null ? true : appState.isMockGps;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SosCountdownScreen(
        onCancel: () => Navigator.of(dialogContext).pop(),
        onConfirm: () async {
          Navigator.of(dialogContext).pop();
          try {
            await appState.activateSos(
              lat: lat,
              lng: lng,
              isMocked: mocked,
              senderName: appState.userProfile?.displayName ?? 'Chính chủ',
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Lỗi gửi cảnh báo SOS lên máy chủ: $e'),
                  backgroundColor: const Color(0xFFD32F2F),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

/// Banner đỏ "TRẠNG THÁI KHẨN CẤP ĐANG BẬT" (cho người gửi) hoặc
/// Banner cảnh báo SOS người thân (cho người nhận) nổi trên đỉnh ứng dụng.
class SosEmergencyBanner extends StatelessWidget {
  const SosEmergencyBanner({
    super.key,
    required this.appState,
    this.onOpenMap,
  });

  final AppState appState;
  final VoidCallback? onOpenMap;

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final SosEvent? active = appState.activeSos;
    if (active == null) return const SizedBox.shrink();

    // 1. Phía Người bấm SOS (Chính chủ)
    if (appState.isMySos) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C),
          boxShadow: const [
            BoxShadow(color: Color(0x55B71C1C), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'TRẠNG THÁI KHẨN CẤP ĐANG BẬT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      appState.isSosDelivered
                          ? 'Đã mã hóa E2EE • Đã gửi tới gia đình lúc ${_formatTime(active.timestamp)}'
                          : appState.sosError != null
                              ? '⚠️ Chưa gửi được tới máy chủ (Đang lưu cục bộ)'
                              : 'Đã mã hóa E2EE • Đang gửi tới gia đình…',
                      style: TextStyle(
                        color: appState.sosError != null ? const Color(0xFFFFCDD2) : Colors.white70,
                        fontSize: 11,
                        fontWeight: appState.sosError != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              child: FilledButton.icon(
                onPressed: () async {
                  try {
                    await appState.resolveSos();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Lỗi cập nhật trạng thái an toàn: $e'),
                          backgroundColor: const Color(0xFFD32F2F),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text(
                  'TÔI ĐÃ AN TOÀN',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.6),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFB71C1C),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Phía Người nhận SOS (Người thân trong gia đình)
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC62828),
        boxShadow: const [
          BoxShadow(color: Color(0x66C62828), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠️ ${active.senderName.toUpperCase()} GỬI SOS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              'Tọa độ: ${active.lat.toStringAsFixed(4)}, ${active.lng.toStringAsFixed(4)} • Pin: ${active.batteryLevel != null ? "${active.batteryLevel}%" : "—"} lúc ${_formatTime(active.timestamp)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_rounded, size: 14),
                  label: const Text(
                    'Mở bản đồ',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => appState.dismissIncomingSos(),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
                  label: const Text(
                    'Tôi đã hỗ trợ',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _SosEmergencyBanner = SosEmergencyBanner;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _myLocation;
  bool _isLoadingLocation = false;
  bool _isMockGps = false;
  StreamSubscription<Position>? _positionStreamSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppScope.read(context);
      appState.initSosListener();
      appState.initLocationListeners();
      _determinePosition();
    });
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Vui lòng bật định vị GPS trên điện thoại')),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⚠️ Ứng dụng cần quyền GPS để xác định vị trí của bạn')),
            );
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Quyền vị trí bị chặn trong Cài đặt')),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final userLoc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _myLocation = userLoc;
          _isMockGps = position.isMocked;
          _isLoadingLocation = false;
        });
        // Đẩy vị trí vào AppState để đánh giá vùng an toàn + trạng thái SOS.
        AppScope.read(context).updatePosition(position);
        _mapController.move(userLoc, 16.0);
      }

      // Đăng ký stream vị trí thời gian thực (distanceFilter ~10m)
      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() {
          _myLocation = LatLng(pos.latitude, pos.longitude);
          _isMockGps = pos.isMocked;
        });
        AppScope.read(context).updatePosition(pos);
      }, onError: (err) {
        debugPrint('[MapScreen] Position stream error: $err');
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lấy vị trí: $e')),
        );
      }
    }
  }

  void _showMemberBottomSheet(FamilyMemberItem member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: member.avatarColor,
                  foregroundColor: Colors.white,
                  child: Text(member.initial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      Text(member.relation, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoRow(label: 'Pin', value: member.battery != null ? '${member.battery}%' : '—'),
            _InfoRow(
              label: 'Vị trí',
              value: member.location != null
                  ? '${member.location!.latitude.toStringAsFixed(4)}, ${member.location!.longitude.toStringAsFixed(4)}'
                  : 'Chưa có dữ liệu vị trí',
            ),
            _InfoRow(label: 'Cập nhật', value: member.lastUpdated ?? 'Chưa có dữ liệu'),
            _InfoRow(
              label: 'Xác thực GPS',
              value: member.isMocked
                  ? '⚠️ Phát hiện Fake GPS / Mock Location'
                  : '✅ GPS thực tế (Hợp lệ)',
            ),
            _InfoRow(label: 'Trạng thái', value: member.isAccepted ? 'Đã kết nối bảo mật' : 'Đang chờ phê duyệt'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final appState = AppScope.read(context);
                  if (appState.sensitiveDataLockEnabled &&
                      !appState.biometricService.isUnlockedThisSession) {
                    final result =
                        await appState.biometricService.authenticateSensitiveAccess(
                      localizedReason:
                          'Xác thực vân tay/mật khẩu để mở tin nhắn bảo mật E2EE',
                    );
                    if (result.name == 'unavailableNeedsPin') {
                      if (!context.mounted) return;
                      final ok = await _showPinFallbackDialog(
                          context, appState.biometricService);
                      if (!ok) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Yêu cầu xác thực mã PIN để truy cập tin nhắn riêng tư'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                        return;
                      }
                    } else if (result != BiometricResult.success) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Yêu cầu xác thực để truy cập tin nhắn riêng tư'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      return;
                    }
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FamilyChatScreen(
                          memberName: member.name,
                          peerEmail: member.email,
                          memberId: member.id,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Nhắn tin bảo mật E2EE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E88E5),
                  side: const BorderSide(color: Color(0xFF1E88E5)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyLocationBottomSheet() {
    if (_myLocation == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.person, size: 30),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vị trí của bạn (Chính chủ)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      Text('Đang chia sẻ trong vòng tròn', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoRow(
              label: 'Tọa độ GPS',
              value: '${_myLocation!.latitude.toStringAsFixed(5)}, ${_myLocation!.longitude.toStringAsFixed(5)}',
            ),
            _InfoRow(
              label: 'Xác thực GPS',
              value: _isMockGps ? '⚠️ Phát hiện Fake GPS' : '✅ GPS thực tế (Hợp lệ)',
            ),
            _InfoRow(label: 'Bảo mật E2EE', value: 'Khóa AES-256 đã kích hoạt'),
          ],
        ),
      ),
    );
  }

  /// BottomSheet liệt kê các vùng an toàn kèm trạng thái vào/ra vùng.
  void _showGeofenceListSheet(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final List<Geofence> fences = appState.geofences;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Vùng an toàn',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Khoảng cách tính bằng công thức Haversine (bề mặt cầu kinh độ)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (fences.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('Chưa có vùng an toàn nào.'),
                    )
                  else
                    ...fences.map(
                      (fence) => _GeofenceTile(
                        fence: fence,
                        distanceMeters: _myLocation == null
                            ? null
                            : GeofenceService.distanceToFence(
                                _myLocation!,
                                fence,
                              ),
                        onToggle: () => appState.toggleGeofence(fence.id),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Hiển thị hộp thoại chia sẻ hành trình bằng mã số 6 chữ số có thời hạn (60 phút).
  void _showTripShareDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _TripShareDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = AppScope.read(context);
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => _buildScaffold(context, appState),
    );
  }

  Widget _buildScaffold(BuildContext context, AppState appState) {
    final focused = appState.focusedLocation;
    if (focused != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(focused, 16.0);
        appState.clearFocusedLocation();
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ gia đình'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Cập nhật vị trí',
            icon: _isLoadingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _determinePosition,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation ?? const LatLng(21.0285, 105.8542),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&hl=vi&x={x}&y={y}&z={z}',
                userAgentPackageName: 'vn.atbm.sos.sos_safe_family',
              ),
              // Vùng an toàn (geofence) — vòng tròn bán kính tính bằng mét.
              // Viền xanh khi đang ở trong vùng, viền cam khi ở ngoài; nền mờ
              // bán trong suốt để vẫn thấy được bản đồ bên dưới.
              CircleLayer(
                circles: [
                  for (final Geofence fence in appState.geofences)
                    if (fence.isEnabled)
                      CircleMarker(
                        point: fence.center,
                        radius: fence.radiusMeters,
                        useRadiusInMeter: true,
                        color: (fence.isInside
                                ? const Color(0xFF43A047)
                                : const Color(0xFFFF9800))
                            .withValues(alpha: 0.2),
                        borderColor: fence.isInside
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFEF6C00),
                        borderStrokeWidth: 2.5,
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Chỉ hiển thị thành viên ĐÃ ĐƯỢC CHẤP THUẬN & có dữ liệu vị trí thực tế
                  ...appState.familyMembers
                      .where((m) => m.isAccepted && m.isSharing && m.location != null)
                      .map(
                    (member) => Marker(
                      point: member.location!,
                      width: 64,
                      height: 64,
                      child: GestureDetector(
                        onTap: () => _showMemberBottomSheet(member),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: member.avatarColor,
                                border: Border.all(
                                  color: member.isMocked
                                      ? const Color(0xFFFF9800)
                                      : Colors.white,
                                  width: member.isMocked ? 3.5 : 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: member.isMocked
                                        ? const Color(0x66FF9800)
                                        : const Color(0x44000000),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  member.initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            if (member.isMocked)
                              Positioned(
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9800),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 3),
                                    ],
                                  ),
                                  child: const Text(
                                    'Fake GPS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // User's own live GPS marker
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: _showMyLocationBottomSheet,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                              ),
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF007AFF),
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x66007AFF), blurRadius: 10, offset: Offset(0, 4)),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.person, color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Top status badge
          if (_myLocation != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _isMockGps ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                      color: _isMockGps ? Colors.orange : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isMockGps
                            ? 'Cảnh báo: GPS có dấu hiệu giả mạo'
                            : 'Đang bảo vệ: GPS thực tế xác thực',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isMockGps ? Colors.orange.shade800 : Colors.green.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Nút mở danh sách vùng an toàn
          Positioned(
            bottom: 30,
            right: 76,
            child: FloatingActionButton.small(
              heroTag: 'geofence_list_btn',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFEF6C00),
              elevation: 4,
              tooltip: 'Vùng an toàn',
              onPressed: () => _showGeofenceListSheet(context, appState),
              child: const Icon(Icons.shield_outlined),
            ),
          ),
          // Nút chia sẻ hành trình bằng mã 6 chữ số (SHA-256 / 60 phút)
          Positioned(
            bottom: 30,
            right: 136,
            child: FloatingActionButton.small(
              heroTag: 'share_trip_btn',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2E7D32),
              elevation: 4,
              tooltip: 'Chia sẻ hành trình',
              onPressed: () => _showTripShareDialog(context),
              child: const Icon(Icons.alt_route_rounded),
            ),
          ),
          // Floating Button to center to current location
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter_gps_btn',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF007AFF),
              elevation: 4,
              onPressed: () {
                if (_myLocation != null) {
                  _mapController.move(_myLocation!, 16.0);
                } else {
                  _determinePosition();
                }
              },
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng trong danh sách vùng an toàn.
class _GeofenceTile extends StatelessWidget {
  const _GeofenceTile({
    required this.fence,
    required this.distanceMeters,
    required this.onToggle,
  });

  final Geofence fence;
  final double? distanceMeters;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final bool inside = fence.isInside;
    final Color accent = fence.isEnabled
        ? (inside ? const Color(0xFF43A047) : const Color(0xFFEF6C00))
        : Colors.grey;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: accent.withValues(alpha: 0.15),
        foregroundColor: accent,
        child: Icon(inside ? Icons.home_rounded : Icons.shield_outlined, size: 22),
      ),
      title: Text(
        fence.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Bán kính ${fence.radiusMeters.round()}m'
        '${distanceMeters == null ? '' : ' • Cách bạn ${distanceMeters!.round()}m'}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                !fence.isEnabled
                    ? 'TẮT'
                    : (inside ? 'ĐANG TRONG VÙNG' : 'Ở NGOÀI VÙNG'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              SizedBox(
                height: 40,
                child: Switch.adaptive(
                  value: fence.isEnabled,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF16A34A),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  void _showAddMemberDialog(BuildContext context, AppState appState) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRelation = 'Bạn bè';
    Color selectedColor = AppState.memberPalette[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Gửi lời mời kết nối gia đình',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.security_rounded, size: 18, color: Color(0xFFE65100)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bảo mật vị trí: Vị trí của người này sẽ chỉ được hiển thị sau khi họ mở app và xác nhận chấp thuận chia sẻ vị trí.',
                            style: TextStyle(fontSize: 12, color: Color(0xFFE65100), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Tên người nhận lời mời *',
                      hintText: 'Ví dụ: Nguyên Vũ, Văn Tuấn, Vợ...',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập tên người nhận';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRelation,
                    decoration: InputDecoration(
                      labelText: 'Mối quan hệ *',
                      prefixIcon: const Icon(Icons.diversity_3_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Bố', child: Text('Bố / Cha')),
                      DropdownMenuItem(value: 'Mẹ', child: Text('Mẹ')),
                      DropdownMenuItem(value: 'Con trai', child: Text('Con trai')),
                      DropdownMenuItem(value: 'Con gái', child: Text('Con gái')),
                      DropdownMenuItem(value: 'Vợ', child: Text('Vợ')),
                      DropdownMenuItem(value: 'Chồng', child: Text('Chồng')),
                      DropdownMenuItem(value: 'Anh/Chị', child: Text('Anh / Chị')),
                      DropdownMenuItem(value: 'Em', child: Text('Em ruột')),
                      DropdownMenuItem(value: 'Bạn bè', child: Text('Bạn bè')),
                      DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedRelation = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email tài khoản Google (Tùy chọn)',
                      hintText: 'nguyen.vu@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Chọn màu đại diện avatar:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: AppState.memberPalette.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => selectedColor = color);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black87 : Colors.white,
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 20, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          appState.sendInvitation(
                            name: nameController.text.trim(),
                            relation: selectedRelation,
                            email: emailController.text.trim().isEmpty
                                ? null
                                : emailController.text.trim(),
                            color: selectedColor,
                          );
                          Navigator.pop(bottomSheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '📨 Đã gửi lời mời tới "${nameController.text.trim()}". Đang chờ đối phương chấp thuận ủy quyền vị trí!',
                              ),
                              backgroundColor: const Color(0xFFE65100),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text(
                        'Gửi lời mời kết nối & chia sẻ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInviteAndJoinDialog(BuildContext context, AppState appState) {
    final codeController = TextEditingController();
    final inviteeNameController = TextEditingController();
    bool isGenerating = false;
    bool isConnecting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.vpn_key_rounded, color: Color(0xFFE53935)),
              SizedBox(width: 10),
              Text('Mã mời & Kết nối', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MÃ MỜI GIA ĐÌNH CỦA BẠN:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE65100),
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (appState.myPairingCode != null) ...[
                        Center(
                          child: Text(
                            appState.myPairingCode!,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8,
                              color: Color(0xFFE53935),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'Gửi mã 6 số này cho người thân để kết nối',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: isGenerating
                                ? null
                                : () async {
                                    setDialogState(() => isGenerating = true);
                                    await appState.generatePairingCode();
                                    if (ctx.mounted) {
                                      setDialogState(() => isGenerating = false);
                                    }
                                  },
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: const Text('Tạo mã khác', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Center(
                          child: FilledButton.icon(
                            onPressed: isGenerating
                                ? null
                                : () async {
                                    setDialogState(() => isGenerating = true);
                                    await appState.generatePairingCode();
                                    if (ctx.mounted) {
                                      setDialogState(() => isGenerating = false);
                                    }
                                  },
                            icon: isGenerating
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Tạo mã mời của bạn'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE65100),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'Bấm nút để sinh mã mời ngẫu nhiên và lưu lên hệ thống',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'HOẶC NHẬP MÃ CỦA NGƯỜI KHÁC:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E88E5),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Mã mời 6 số',
                    hintText: 'Ví dụ: 789123',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: inviteeNameController,
                  decoration: InputDecoration(
                    labelText: 'Tên người mời / người thân',
                    hintText: 'Ví dụ: Phạm Nguyên Vũ',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: isConnecting
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      final name = inviteeNameController.text.trim();
                      if (code.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập đúng 6 chữ số mã mời')),
                        );
                        return;
                      }

                      setDialogState(() => isConnecting = true);
                      final success = await appState.connectWithPairingCode(
                        code: code,
                        memberName: name.isNotEmpty ? name : null,
                      );

                      if (ctx.mounted) {
                        setDialogState(() => isConnecting = false);
                      }

                      if (!success) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ Mã không hợp lệ hoặc đã hết hạn'),
                              backgroundColor: Color(0xFFD32F2F),
                            ),
                          );
                        }
                        return;
                      }

                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Đã kết nối thành công với "${name.isNotEmpty ? name : 'Mã $code'}"!'),
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
              child: isConnecting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kết nối ngay'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMember(BuildContext context, AppState appState, FamilyMemberItem member) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ngắt kết nối thành viên'),
        content: Text(
          'Bạn có chắc muốn xóa "${member.name}" (${member.relation}) khỏi vòng tròn gia đình?\n\n'
          'Sau khi xóa, ứng dụng sẽ thu hồi khóa chia sẻ vị trí và kênh chat bảo mật E2EE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () {
              appState.removeFamilyMember(member.id);
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã ngắt kết nối với "${member.name}"'),
                ),
              );
            },
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.read(context);

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final members = appState.familyMembers;
        final incoming = members.where((m) => m.isPendingIncoming).toList();
        final outgoing = members.where((m) => m.isPendingOutgoing).toList();
        final accepted = members.where((m) => m.isAccepted).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Vòng tròn gia đình'),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Gửi lời mời kết nối',
                icon: const Icon(Icons.person_add_rounded, color: Color(0xFF1E88E5)),
                onPressed: () => _showAddMemberDialog(context, appState),
              ),
              IconButton(
                tooltip: 'Mã mời kết nối',
                icon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF1E88E5)),
                onPressed: () => _showInviteAndJoinDialog(context, appState),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: appState.isMyLocationSharingEnabled
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: appState.isMyLocationSharingEnabled
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: appState.isMyLocationSharingEnabled
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          appState.isMyLocationSharingEnabled
                              ? Icons.location_on_rounded
                              : Icons.location_off_rounded,
                          color: appState.isMyLocationSharingEnabled
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Chia sẻ vị trí của tôi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: appState.isMyLocationSharingEnabled
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    appState.isMyLocationSharingEnabled ? 'Đang phát' : 'Đã tạm dừng',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: appState.isMyLocationSharingEnabled
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              appState.isMyLocationSharingEnabled
                                  ? 'Ủy quyền 2 chiều & Mã hóa E2EE X25519'
                                  : 'Tạm dừng chia sẻ tọa độ tới người thân',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: appState.isMyLocationSharingEnabled
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: appState.isMyLocationSharingEnabled,
                        onChanged: (val) => appState.setMyLocationSharing(val),
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF16A34A),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (members.isEmpty)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.diversity_3_rounded,
                                size: 68,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Chưa có thành viên gia đình',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Gửi lời mời kết nối tới người thân. Vị trí của hai bên chỉ được hiển thị sau khi đối phương bấm Chấp nhận trên điện thoại của họ (bảo vệ quyền riêng tư PII).',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: () => _showAddMemberDialog(context, appState),
                                icon: const Icon(Icons.person_add_alt_1_rounded),
                                label: const Text(
                                  'Gửi lời mời kết nối',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E88E5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () => _showInviteAndJoinDialog(context, appState),
                                icon: const Icon(Icons.pin_outlined),
                                label: const Text(
                                  'Nhập mã mời kết nối',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E88E5),
                                  side: const BorderSide(color: Color(0xFF1E88E5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: [
                        // --- 1. LỜI MỜI ĐẾN (CẦN PHÊ DUYỆT CHIA SẺ VỊ TRÍ) ---
                        if (incoming.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFB74D), width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.mark_email_unread_rounded, color: Color(0xFFE65100), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Yêu cầu chia sẻ vị trí mới (${incoming.length})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100), fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...incoming.map(
                                  (req) => Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    elevation: 0,
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: req.avatarColor,
                                                child: Text(req.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(req.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                    Text('${req.relation} • Yêu cầu xem vị trí của bạn', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              OutlinedButton(
                                                onPressed: () => appState.rejectInvitation(req.id),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red.shade700,
                                                  side: BorderSide(color: Colors.red.shade300),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                ),
                                                child: const Text('Từ chối'),
                                              ),
                                              const SizedBox(width: 8),
                                              FilledButton.icon(
                                                onPressed: () => appState.acceptInvitation(req.id),
                                                icon: const Icon(Icons.check, size: 16),
                                                label: const Text('Đồng ý chia sẻ'),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: const Color(0xFF2E7D32),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // --- 2. LỜI MỜI GỬI ĐI (CHỜ ĐỐI PHƯƠNG CHẤP THUẬN) ---
                        if (outgoing.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFF57C00)),
                                const SizedBox(width: 6),
                                Text(
                                  'Đang chờ đối phương chấp thuận (${outgoing.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF57C00)),
                                ),
                              ],
                            ),
                          ),
                          ...outgoing.map(
                            (out) => Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 0,
                              color: const Color(0xFFF8FAFC),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: out.avatarColor.withValues(alpha: 0.6),
                                          child: Text(out.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(out.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                              Text('${out.relation} • ⏳ Vị trí đang bị ẩn', style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                          tooltip: 'Thu hồi lời mời',
                                          onPressed: () => appState.removeFamilyMember(out.id),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, size: 14, color: Colors.black54),
                                          const SizedBox(width: 6),
                                          const Expanded(
                                            child: Text(
                                              'Vị trí sẽ hiển thị ngay khi đối phương bấm đồng ý.',
                                              style: TextStyle(fontSize: 11, color: Colors.black87),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => appState.simulatePeerApproval(out.id),
                                            icon: const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF2E7D32)),
                                            label: const Text(
                                              'Mô phỏng: Đồng ý',
                                              style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                                            ),
                                            style: TextButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // --- 3. THÀNH VIÊN ĐÃ KẾT NỐI (HIỂN THỊ VỊ TRÍ & CHAT E2EE) ---
                        if (accepted.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 6),
                                Text(
                                  'Thành viên đã kết nối (${accepted.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2E7D32)),
                                ),
                              ],
                            ),
                          ),
                          ...accepted.map(
                            (member) => Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FamilyChatScreen(
                                        memberName: member.name,
                                        peerEmail: member.email,
                                        memberId: member.id,
                                      ),
                                    ),
                                  );
                                },
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: member.avatarColor,
                                  foregroundColor: Colors.white,
                                  child: Text(
                                    member.initial,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                title: Text(
                                  member.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  '${member.relation} • Pin: ${member.battery != null ? "${member.battery}%" : "—"}\n${!member.isSharing ? "⏸️ Đã tạm dừng nhận vị trí" : member.location != null ? "✅ Vị trí trực tiếp • Chat E2EE" : "📍 Chưa có dữ liệu vị trí • Chat E2EE"}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: member.isSharing ? Colors.black87 : Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF1E88E5)),
                                      tooltip: 'Nhắn tin bảo mật E2EE',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FamilyChatScreen(
                                              memberName: member.name,
                                              peerEmail: member.email,
                                              memberId: member.id,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    Switch.adaptive(
                                      value: member.isSharing,
                                      onChanged: (value) {
                                        appState.toggleMemberSharing(member.id, value);
                                      },
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: const Color(0xFF16A34A),
                                      inactiveThumbColor: Colors.white,
                                      inactiveTrackColor: const Color(0xFFCBD5E1),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade600),
                                      tooltip: 'Ngắt kết nối',
                                      onPressed: () => _confirmDeleteMember(context, appState, member),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (members.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _showAddMemberDialog(context, appState),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Gửi lời mời'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showInviteAndJoinDialog(context, appState),
                          icon: const Icon(Icons.vpn_key_rounded),
                          label: const Text('Mã mời'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E88E5),
                            side: const BorderSide(color: Color(0xFF1E88E5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  static String auditSubtitle(String log) {
    if (log.contains('MÔ PHỎNG') || log.contains('Mô phỏng')) {
      return 'Mô phỏng (Simulation) • Dữ liệu kiểm thử';
    }
    if (log.contains('SOS')) {
      return 'Sự kiện khẩn cấp SOS • Chống giả mạo & Replay Guard';
    }
    if (log.contains('TỪ CHỐI')) {
      return 'Từ chối ủy quyền • Bảo vệ quyền riêng tư PII';
    }
    if (log.contains('ỦY QUYỀN') || log.contains('CHẤP THUẬN') || log.contains('Đồng ý')) {
      return 'Ủy quyền truy cập • Xác thực Handshake 2 chiều';
    }
    if (log.contains('LỜI MỜI') || log.contains('YÊU CẦU') || log.contains('MÃ MỜI')) {
      return 'Kết nối thành viên • Ghép đôi vòng tròn an toàn';
    }
    if (log.contains('XÁC THỰC') || log.contains('Keystore') || log.contains('X25519')) {
      return 'Quản lý định danh • Android Keystore X25519';
    }
    if (log.contains('MÃ HÓA') || log.contains('E2EE')) {
      return 'Mã hóa đầu cuối • ECDH X25519 & AES-256-GCM';
    }
    return 'Nhật ký bảo mật hệ thống';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.read(context);

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final auditLogs = appState.auditLogs;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nhật ký kiểm toán E2EE'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: auditLogs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có bản ghi nhật ký kiểm toán nào',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: auditLogs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = auditLogs[index];
                    final isSos = log.contains('SOS');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isSos ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD),
                        foregroundColor:
                            isSos ? const Color(0xFFE53935) : const Color(0xFF1E88E5),
                        child: Icon(
                          isSos ? Icons.warning_amber_rounded : Icons.history_rounded,
                        ),
                      ),
                      title: Text(
                        log,
                        style: TextStyle(
                          fontWeight: isSos ? FontWeight.bold : FontWeight.normal,
                          color: isSos ? const Color(0xFFB71C1C) : const Color(0xFF18191F),
                        ),
                      ),
                      subtitle: Text(
                        auditSubtitle(log),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showTestAccountDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController(text: state.userProfile?.displayName ?? '');
    final emailCtrl = TextEditingController(text: state.currentUserEmail ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đăng nhập tài khoản kiểm thử',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tự động sinh và nạp cặp khóa X25519 Keystore riêng biệt cho tài khoản này để kiểm thử đa tài khoản.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Tên hiển thị',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email tài khoản',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await state.signInWithTestAccount(
                      email: emailCtrl.text.trim(),
                      displayName: nameCtrl.text.trim(),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Đã đăng nhập: ${nameCtrl.text.trim()} (Keystore Active)'),
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Đăng nhập & Kích hoạt Keystore', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.userProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thẻ thông tin cá nhân / Đăng nhập
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: user != null
                ? Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF1E88E5),
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF18191F),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '🛡 E2EE Keystore Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: Color(0xFFECEFF1),
                            child: Icon(
                              Icons.account_circle_outlined,
                              size: 34,
                              color: Color(0xFF78909C),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Chưa đăng nhập',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF263238),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Đăng nhập Google để kích hoạt E2EE Keystore',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: state.isAuthLoading
                              ? null
                              : () async {
                                  try {
                                    await state.signInWithGoogle();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Đăng nhập thất bại: $e'),
                                          backgroundColor: Colors.red.shade700,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: state.isAuthLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded, size: 20),
                          label: Text(
                            state.isAuthLoading
                                ? 'Đang xác thực...'
                                : 'Đăng nhập với Google',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: state.isAuthLoading
                              ? null
                              : () => _showTestAccountDialog(context, state),
                          icon: const Icon(Icons.science_outlined, size: 19),
                          label: const Text(
                            'Đăng nhập tài khoản kiểm thử',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Nhóm Cài đặt & Bảo mật
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'CÀI ĐẶT & BẢO MẬT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF78909C),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFE53935),
                    ),
                  ),
                  title: const Text(
                    'Bảo mật',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Khóa vân tay, chống chụp màn hình, audit log',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SecurityScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                  title: const Text(
                    'Thiết bị liên kết',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Thông tin thiết bị không khả dụng',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Đang dùng',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.key_rounded,
                      color: Color(0xFF7E57C2),
                    ),
                  ),
                  title: const Text(
                    'Khóa mật mã X25519',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    user != null
                        ? 'Vân tay: ${user.publicKeyFingerprint}'
                        : 'Khóa riêng tư lưu trữ trong Android Keystore',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: user != null
                      ? IconButton(
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF7E57C2),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (ctx) => Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.security, color: Color(0xFF7E57C2)),
                                        SizedBox(width: 8),
                                        Text(
                                          'Chứng Chỉ Mật Mã X25519',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Mã vân tay an toàn (Out-of-band Fingerprint):',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      user.publicKeyFingerprint,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E88E5),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Khóa công khai (Public Key Base64):',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      user.publicKeyB64,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.verified,
                                          color: Color(0xFF2E7D32),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Khóa private được bảo vệ bởi Android Keystore (TEE Hardware-backed)',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF43A047),
                          size: 20,
                        ),
                ),
                if (user != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                    title: const Text(
                      'Đăng xuất',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                    subtitle: const Text(
                      'Đăng xuất tài khoản khỏi thiết bị này',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Xác nhận đăng xuất'),
                          content: const Text(
                            'Bạn có chắc chắn muốn đăng xuất? Khóa riêng tư trong Keystore vẫn được bảo vệ an toàn cho lần đăng nhập tới.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Hủy'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await state.signOut();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Thông tin ứng dụng
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'THÔNG TIN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF78909C),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            color: Colors.white,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEFF1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF546E7A),
                ),
              ),
              title: const Text(
                'SOS An Toàn Gia Đình',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Phiên bản 1.0.0 • Đồ án An Toàn Bảo Mật',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.read(context).refreshTamperReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = AppScope.read(context);

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final auditLogs = appState.auditLogs;
        final TamperReport? tamper = appState.tamperReport;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bảo mật & cài đặt'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Khóa sinh trắc học vùng nhạy cảm',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Bảo vệ Vòng tròn, Nhật ký & Tin nhắn (Bản đồ & SOS luôn mở khẩn cấp)',
                ),
                value: appState.sensitiveDataLockEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF1E88E5),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFCBD5E1),
                onChanged: (value) => appState.setSensitiveDataLock(value),
              ),
              const Divider(),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Chống chụp màn hình',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Bật FLAG_SECURE native để chặn chụp & quay màn hình',
                ),
                value: appState.flagSecureEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF1E88E5),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFCBD5E1),
                onChanged: (value) => appState.setFlagSecure(value),
              ),
              const Divider(),
              const SizedBox(height: 8),
              // Thẻ kiểm tra toàn vẹn thiết bị (Root & GPS giả lập)
              Card(
                elevation: 0,
                color: tamper != null && !tamper.isTrusted
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFE8F5E9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: tamper != null && !tamper.isTrusted
                        ? const Color(0xFFFFB74D)
                        : const Color(0xFFA5D6A7),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            tamper != null && !tamper.isTrusted
                                ? Icons.warning_rounded
                                : Icons.verified_user_rounded,
                            color: tamper != null && !tamper.isTrusted
                                ? const Color(0xFFE65100)
                                : const Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tamper != null && !tamper.isTrusted
                                ? 'Cảnh báo toàn vẹn thiết bị'
                                : 'Toàn vẹn thiết bị an toàn',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: tamper != null && !tamper.isTrusted
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: 'Kiểm tra lại',
                            onPressed: () => appState.refreshTamperReport(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildIntegrityRow(
                        label: 'Trạng thái Root:',
                        value: tamper?.rootLabel ?? 'Đang kiểm tra...',
                        isSafe: !(tamper?.isRooted ?? false),
                      ),
                      const SizedBox(height: 4),
                      _buildIntegrityRow(
                        label: 'Xác thực GPS:',
                        value: tamper?.gpsLabel ?? 'Đang kiểm tra...',
                        isSafe: !(tamper?.isMockLocation ?? false),
                      ),
                      const SizedBox(height: 4),
                      _buildIntegrityRow(
                        label: 'Bảo vệ màn hình:',
                        value: tamper?.screenCaptureLabel ?? 'FLAG_SECURE',
                        isSafe: tamper?.isScreenCaptureProtected ?? false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              ExpansionTile(
                leading: const Icon(Icons.history_rounded, color: Color(0xFFE53935)),
                title: const Text(
                  'Nhật ký kiểm toán & xem vị trí',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: auditLogs.isEmpty
                    ? const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Chưa có sự kiện nào trong nhật ký kiểm toán.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                      ]
                    : auditLogs
                        .map(
                          (log) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.access_time_filled, size: 16, color: Color(0xFF607D8B)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(log)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntegrityRow({
    required String label,
    required String value,
    required bool isSafe,
  }) {
    return Row(
      children: [
        Icon(
          isSafe ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 16,
          color: isSafe ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isSafe ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Hộp thoại chia sẻ hành trình ngẫu nhiên 6 chữ số với thời hạn 60 phút.
class _TripShareDialog extends StatefulWidget {
  const _TripShareDialog();

  @override
  State<_TripShareDialog> createState() => _TripShareDialogState();
}

class _TripShareDialogState extends State<_TripShareDialog> {
  final TripShareService _service = TripShareService();
  String? _code;
  TripShare? _share;
  Timer? _countdownTimer;
  int _remainingSeconds = 3600;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTrip();
  }

  Future<void> _initTrip() async {
    final (code, share) = await _service.createTripShare();
    if (mounted) {
      setState(() {
        _code = code;
        _share = share;
        _remainingSeconds = share.remainingSecondsAt(DateTime.now());
        _isLoading = false;
      });
      _startTimer();
    }
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_share == null) return;
      final remaining = _share!.remainingSecondsAt(DateTime.now());
      if (remaining <= 0) {
        timer.cancel();
      }
      setState(() {
        _remainingSeconds = remaining;
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.alt_route_rounded, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chia sẻ hành trình',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Cung cấp mã 6 chữ số này cho người thân để theo dõi vị trí tạm thời:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFAED581)),
                    ),
                    child: Text(
                      _code?.split('').join('  ') ?? '------',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFE65100)),
                      const SizedBox(width: 6),
                      Text(
                        'Tự hủy sau: ${_formatDuration(_remainingSeconds)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEFF1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mã băm SHA-256 (bảo vệ trên đường truyền):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF455A64)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _share?.codeHash ?? '',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF607D8B)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
