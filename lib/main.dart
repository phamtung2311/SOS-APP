import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sos_safe_family/presentation/screens/family_chat_screen.dart';

void main() {
  runApp(const SOSFamilyApp());
}

class SOSFamilyApp extends StatelessWidget {
  const SOSFamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    SecurityScreen(),
  ];

  void _showSosDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF18191F),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Cảnh báo SOS', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Mô phỏng kích hoạt SOS. Chế độ khẩn cấp đang được gửi đến các thành viên trong gia đình.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButton: GestureDetector(
        onLongPressStart: (_) {
          _sosTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _showSosDialog();
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (value) => setState(() => _selectedIndex = value),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE53935),
        unselectedItemColor: const Color(0xFF546E7A),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Bản đồ'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Vòng tròn'),
          BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), activeIcon: Icon(Icons.shield), label: 'Bảo mật'),
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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final userLoc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _myLocation = userLoc;
          _isMockGps = position.isMocked;
          _isLoadingLocation = false;
        });
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
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FamilyChatScreen(memberName: member.name),
                    ),
                  );
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

  @override
  Widget build(BuildContext context) {
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
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'vn.atbm.sos.sos_safe_family',
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
                                color: const Color(0xFF007AFF).withOpacity(0.2),
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
                  color: Colors.white.withOpacity(0.95),
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

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _fingerprintLock = true;
  bool _flagSecure = true;

  @override
  Widget build(BuildContext context) {
    final auditLogs = [
      '08:30 - Bố đã xem vị trí của bạn',
      '09:15 - Mẹ đã xem vị trí của bạn',
      '11:40 - Con đã xem vị trí của bạn',
    ];

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
            title: const Text('Khóa vân tay', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Yêu cầu xác thực trước khi mở ứng dụng'),
            value: _fingerprintLock,
            activeThumbColor: const Color(0xFFE53935),
            activeTrackColor: const Color(0xFFF8BBD0),
            onChanged: (value) => setState(() => _fingerprintLock = value),
          ),
          const Divider(),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chống chụp màn hình', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Bật FLAG_SECURE để bảo vệ nội dung màn hình'),
            value: _flagSecure,
            activeThumbColor: const Color(0xFFE53935),
            activeTrackColor: const Color(0xFFF8BBD0),
            onChanged: (value) => setState(() => _flagSecure = value),
          ),
          const Divider(),
          ExpansionTile(
            leading: const Icon(Icons.history_rounded, color: Color(0xFFE53935)),
            title: const Text('Nhật ký ai đã xem vị trí của tôi', style: TextStyle(fontWeight: FontWeight.w600)),
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
  }
}
