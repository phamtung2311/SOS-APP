import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sos_safe_family/data/models/geofence.dart';

/// Loại sự kiện chuyển trạng thái của một vùng an toàn.
enum GeofenceTransitionType {
  /// Người dùng vừa đi vào vùng an toàn.
  enter,

  /// Người dùng vừa rời khỏi vùng an toàn.
  exit,
}

/// Một sự kiện chuyển trạng thái (ENTER / EXIT) của một vùng an toàn.
class GeofenceTransition {
  const GeofenceTransition({
    required this.fence,
    required this.type,
    required this.distanceMeters,
  });

  /// Vùng an toàn phát sinh sự kiện.
  final Geofence fence;

  /// Loại sự kiện.
  final GeofenceTransitionType type;

  /// Khoảng cách hiện tại tới tâm vùng (mét).
  final double distanceMeters;

  bool get isEnter => type == GeofenceTransitionType.enter;
  bool get isExit => type == GeofenceTransitionType.exit;

  @override
  String toString() =>
      'GeofenceTransition(${fence.id}, ${type.name}, ${distanceMeters.toStringAsFixed(1)}m)';
}

/// Kết quả của một lần đánh giá các vùng an toàn tại một vị trí.
class GeofenceUpdate {
  const GeofenceUpdate({
    required this.transitions,
    required this.fences,
  });

  /// Các sự kiện ENTER / EXIT phát sinh lần này (rỗng nếu không đổi trạng thái).
  final List<GeofenceTransition> transitions;

  /// Danh sách vùng với `isInside` đã cập nhật (sẵn sàng lưu về trạng thái trước
  /// cho lần đánh giá kế tiếp).
  final List<Geofence> fences;

  bool get hasTransitions => transitions.isNotEmpty;
}

/// Dịch vụ đánh giá vùng an toàn (geofence).
///
/// **Thuật toán Haversine** được dùng để tính khoảng cách trên bề mặt cầu
/// kinh độ (great-circle distance) giữa hai tọa độ — chính xác hơn nhiều so
/// với khoảng cách Euclid phẳng, đặc biệt ở các vĩ độ cao.
///
/// Công thức:
///
/// ```text
/// a = sin²(Δφ/2) + cos φ₁ · cos φ₂ · sin²(Δλ/2)
/// c = 2 · atan2(√a, √(1-a))
/// d = R · c
/// ```
class GeofenceService {
  /// Bán kính Trái Đất theo [AppConstants.earthRadiusMeters].
  static const double earthRadiusMeters = 6371000.0;

  /// Tính khoảng cách (mét) giữa hai tọa độ bằng công thức Haversine.
  ///
  /// [lat1]/[lng1] và [lat2]/[lng2] là tọa độ **độ** (degree).
  static double haversineDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const double toRad = math.pi / 180.0;

    final double phi1 = lat1 * toRad;
    final double phi2 = lat2 * toRad;
    final double deltaPhi = (lat2 - lat1) * toRad;
    final double deltaLambda = (lng2 - lng1) * toRad;

    final double a = math.pow(math.sin(deltaPhi / 2), 2) +
        math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(deltaLambda / 2), 2);

    // a luôn nằm trong [0, 1]; clamp để tránh NaN do sai số số thực.
    final double clampedA = a.clamp(0.0, 1.0);
    final double c = 2 * math.atan2(math.sqrt(clampedA), math.sqrt(1 - clampedA));

    return earthRadiusMeters * c;
  }

  /// Tính khoảng cách (mét) giữa hai [LatLng].
  static double distanceBetween(LatLng a, LatLng b) {
    return haversineDistance(
      lat1: a.latitude,
      lng1: a.longitude,
      lat2: b.latitude,
      lng2: b.longitude,
    );
  }

  /// Khoảng cách (mét) từ vị trí hiện tại tới tâm của [fence].
  static double distanceToFence(LatLng position, Geofence fence) {
    return haversineDistance(
      lat1: position.latitude,
      lng1: position.longitude,
      lat2: fence.centerLatitude,
      lng2: fence.centerLongitude,
    );
  }

  /// Kiểm tra vị trí hiện tại có nằm trong vùng an toàn hay không.
  ///
  /// Trả về `true` khi khoảng cách tới tâm vùng **≤** bán kính.
  static bool checkGeofenceStatus(Position currentPos, Geofence fence) {
    return haversineDistance(
          lat1: currentPos.latitude,
          lng1: currentPos.longitude,
          lat2: fence.centerLatitude,
          lng2: fence.centerLongitude,
        ) <=
        fence.radiusMeters;
  }

  /// Phiên bản [checkGeofenceStatus] nhận [LatLng] (thuận tiện cho test).
  static bool isInsideFence(LatLng position, Geofence fence) {
    return distanceToFence(position, fence) <= fence.radiusMeters;
  }

  /// Phát hiện các sự kiện chuyển trạng thái ENTER / EXIT.
  ///
  /// So sánh trạng thái `isInside` đã lưu sẵn trong [fence] (trạng thái trước)
  /// với trạng thái được tính từ [currentPos] (trạng thái sau). Nhờ vậy, khi
  /// người dùng đứng yên trong một vùng, không có sự kiện nào được phát ra —
  /// tránh spam cảnh báo.
  ///
  /// Các vùng có `isEnabled == false` bị bỏ qua.
  ///
  /// Dùng [updateFenceStatuses] để cập nhật lại `isInside` cho danh sách vùng
  /// sau khi đã xử lý kết quả.
  static List<GeofenceTransition> evaluateTransitions({
    required LatLng currentPos,
    required List<Geofence> fences,
  }) {
    final transitions = <GeofenceTransition>[];

    for (final fence in fences) {
      if (!fence.isEnabled) continue;

      final bool nowInside = isInsideFence(currentPos, fence);
      final bool wasInside = fence.isInside;

      if (nowInside == wasInside) continue;

      transitions.add(
        GeofenceTransition(
          fence: fence,
          type: nowInside
              ? GeofenceTransitionType.enter
              : GeofenceTransitionType.exit,
          distanceMeters: distanceToFence(currentPos, fence),
        ),
      );
    }

    return transitions;
  }

  /// Đánh giá toàn bộ vùng an toàn tại một mốc thời gian.
  ///
  /// Trả về đồng thời danh sách sự kiện chuyển trạng thái **và** danh sách vùng
  /// đã cập nhật `isInside` — tiện cho việc "so sánh trạng thái trước và sau"
  /// trong một lần gọi.
  static GeofenceUpdate evaluateGeofenceUpdate({
    required LatLng currentPos,
    required List<Geofence> fences,
  }) {
    final transitions = evaluateTransitions(currentPos: currentPos, fences: fences);
    final updated = updateFenceStatuses(currentPos: currentPos, fences: fences);
    return GeofenceUpdate(transitions: transitions, fences: updated);
  }

  /// Trả về danh sách vùng mới với `isInside` đã cập nhật theo [currentPos].
  ///
  /// Đây là bước "commit trạng thái" sau khi đã xử lý [evaluateTransitions].
  static List<Geofence> updateFenceStatuses({
    required LatLng currentPos,
    required List<Geofence> fences,
  }) {
    return fences.map((fence) {
      if (!fence.isEnabled) return fence;
      return fence.copyWith(isInside: isInsideFence(currentPos, fence));
    }).toList();
  }

  /// Danh sách vùng an toàn mẫu (seed data) cho bản demo.
  static List<Geofence> seedGeofences() => const [
        Geofence(
          id: 'fence_home',
          name: 'Nhà riêng',
          centerLatitude: 21.0285,
          centerLongitude: 105.8542,
          radiusMeters: 100,
        ),
        Geofence(
          id: 'fence_work',
          name: 'Cơ quan / Trường học',
          centerLatitude: 21.0289,
          centerLongitude: 105.7837,
          radiusMeters: 200,
        ),
      ];
}
