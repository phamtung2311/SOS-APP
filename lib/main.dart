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
      if (result != BiometricResult.success &&
          result != BiometricResult.unavailable) {
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
                  child: _SosEmergencyBanner(appState: appState),
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
          await appState.activateSos(
            lat: lat,
            lng: lng,
            isMocked: mocked,
            senderName: 'Chính chủ',
          );
        },
      ),
    );
  }
}

/// Banner đỏ "TRẠNG THÁI KHẨN CẤP ĐANG BẬT" nổi trên đỉnh ứng dụng.
class _SosEmergencyBanner extends StatelessWidget {
  const _SosEmergencyBanner({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final SosEvent? active = appState.activeSos;
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
                if (active != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Đã mã hóa E2EE • Gửi tới gia đình lúc ${active.timestamp.hour.toString().padLeft(2, '0')}:${active.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            child: FilledButton.icon(
              onPressed: () => appState.resolveSos(),
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
}

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

  final List<FamilyMember> _members = const [
    FamilyMember(
      name: 'Bố',
      relation: 'Cha',
      initial: 'B',
      color: Color(0xFF7E57C2),
      battery: 88,
      lastUpdated: '2 phút trước',
      location: LatLng(21.0285, 105.8542),
    ),
    FamilyMember(
      name: 'Mẹ',
      relation: 'Mẹ',
      initial: 'M',
      color: Color(0xFF43A047),
      battery: 75,
      lastUpdated: '1 phút trước',
      location: LatLng(21.0185, 105.8021),
    ),
    FamilyMember(
      name: 'Con',
      relation: 'Con trai',
      initial: 'C',
      color: Color(0xFF1E88E5),
      battery: 91,
      lastUpdated: '30 giây trước',
      location: LatLng(21.0441, 105.8482),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determinePosition();
    });
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lấy vị trí: $e')),
        );
      }
    }
  }

  void _showMemberBottomSheet(FamilyMember member) {
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
                  backgroundColor: member.color,
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
            _InfoRow(label: 'Pin', value: '${member.battery}%'),
            _InfoRow(label: 'Cập nhật', value: member.lastUpdated),
            _InfoRow(label: 'Trạng thái', value: 'An toàn'),
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
                    if (result != BiometricResult.success &&
                        result != BiometricResult.unavailable) {
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
                        builder: (_) => FamilyChatScreen(memberName: member.name),
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
                  // Family members
                  ..._members.map(
                    (member) => Marker(
                      point: member.location,
                      width: 52,
                      height: 52,
                      child: GestureDetector(
                        onTap: () => _showMemberBottomSheet(member),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: member.color,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 4)),
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
                  activeThumbColor: const Color(0xFFE53935),
                  activeTrackColor: const Color(0xFFE53935),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FamilyMember {
  final String name;
  final String relation;
  final String initial;
  final Color color;
  final int battery;
  final String lastUpdated;
  final LatLng location;

  const FamilyMember({
    required this.name,
    required this.relation,
    required this.initial,
    required this.color,
    required this.battery,
    required this.lastUpdated,
    required this.location,
  });
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
  final List<_CircleMember> _members = [
    _CircleMember(name: 'Bố', relation: 'Cha', isSharing: true, avatarColor: const Color(0xFF7E57C2)),
    _CircleMember(name: 'Mẹ', relation: 'Mẹ', isSharing: true, avatarColor: const Color(0xFF43A047)),
    _CircleMember(name: 'Con', relation: 'Con trai', isSharing: false, avatarColor: const Color(0xFF1E88E5)),
  ];

  void _showInviteCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mời thành viên'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Mã mời gia đình'),
            SizedBox(height: 12),
            Text(
              '482615',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Color(0xFFE53935)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vòng tròn gia đình'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              color: const Color(0xFFEAF5FF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF1E88E5)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chia sẻ vị trí của tôi', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text('Đang bật cho các thành viên gần đây'),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: true,
                      onChanged: (_) {},
                      activeThumbColor: const Color(0xFFE53935),
                      activeTrackColor: const Color(0xFFE53935),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: _members.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FamilyChatScreen(memberName: member.name),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: member.avatarColor,
                      foregroundColor: Colors.white,
                      child: Text(member.name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    title: Text(member.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${member.relation} • Chạm để chat E2EE'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF1E88E5)),
                          tooltip: 'Nhắn tin bảo mật E2EE',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FamilyChatScreen(memberName: member.name),
                              ),
                            );
                          },
                        ),
                        Switch.adaptive(
                          value: member.isSharing,
                          onChanged: (value) {
                            setState(() {
                              member.isSharing = value;
                            });
                          },
                          activeThumbColor: const Color(0xFFE53935),
                          activeTrackColor: const Color(0xFFE53935),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showInviteCode,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Mời thành viên'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleMember {
  final String name;
  final String relation;
  final Color avatarColor;
  bool isSharing;

  _CircleMember({
    required this.name,
    required this.relation,
    required this.avatarColor,
    required this.isSharing,
  });
}

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.read(context);

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final auditLogs = <String>[
          ...appState.auditLogs,
          '08:30 - Bố đã xem vị trí của bạn',
          '09:15 - Mẹ đã xem vị trí của bạn',
          '11:40 - Con đã xem vị trí của bạn',
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nhật ký kiểm toán E2EE'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: ListView.separated(
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
                subtitle: const Text(
                  'Xác thực chữ ký & mã hóa E2EE',
                  style: TextStyle(fontSize: 11.5),
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
                    'Xiaomi Redmi Note 11 (220333QAG)',
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
        final auditLogs = <String>[
          ...appState.auditLogs,
          '08:30 - Bố đã xem vị trí của bạn',
          '09:15 - Mẹ đã xem vị trí của bạn',
          '11:40 - Con đã xem vị trí của bạn',
        ];
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
                activeThumbColor: const Color(0xFFE53935),
                activeTrackColor: const Color(0xFFF8BBD0),
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
                activeThumbColor: const Color(0xFFE53935),
                activeTrackColor: const Color(0xFFF8BBD0),
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
                children: auditLogs
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
