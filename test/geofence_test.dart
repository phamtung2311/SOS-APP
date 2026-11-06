import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sos_safe_family/data/models/geofence.dart';
import 'package:sos_safe_family/data/services/geofence_service.dart';

/// Tạo một [Position] giả lập để kiểm thử [GeofenceService.checkGeofenceStatus].
Position fakePosition(double lat, double lng) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    isMocked: false,
  );
}

void main() {
  group('Geofence model', () {
    test('copyWith chỉ thay đổi trường được chỉ định', () {
      const fence = Geofence(
        id: 'f1',
        name: 'Nhà riêng',
        centerLatitude: 21.0285,
        centerLongitude: 105.8542,
        radiusMeters: 100,
      );

      final updated = fence.copyWith(isInside: true);
      expect(updated.isInside, isTrue);
      expect(updated.id, fence.id);
      expect(updated.name, fence.name);
      expect(updated.radiusMeters, fence.radiusMeters);
      expect(fence.isInside, isFalse, reason: 'Bản gốc không bị thay đổi');
    });

    test('toJson / fromJson round-trip giữ nguyên dữ liệu', () {
      const fence = Geofence(
        id: 'f2',
        name: 'Trường học',
        centerLatitude: 21.0289,
        centerLongitude: 105.7837,
        radiusMeters: 200,
        isEnabled: true,
        isInside: true,
      );

      final restored = Geofence.fromJson(fence.toJson());
      expect(restored.id, fence.id);
      expect(restored.name, fence.name);
      expect(restored.centerLatitude, closeTo(fence.centerLatitude, 1e-9));
      expect(restored.centerLongitude, closeTo(fence.centerLongitude, 1e-9));
      expect(restored.radiusMeters, closeTo(fence.radiusMeters, 1e-9));
      expect(restored.isEnabled, isTrue);
      expect(restored.isInside, isTrue);
    });

    test('fromJson chịu được JSON thiếu trường', () {
      final fence = Geofence.fromJson(const {'id': 'f3'});
      expect(fence.name, '');
      expect(fence.radiusMeters, 0);
      expect(fence.isEnabled, isTrue);
      expect(fence.isInside, isFalse);
    });
  });

  group('Haversine — độ chính xác công thức', () {
    test('Hà Nội → TP. Hồ Chí Minh ≈ 1 137 867 m', () {
      final double d = GeofenceService.haversineDistance(
        lat1: 21.0285, // Hà Nội
        lng1: 105.8462,
        lat2: 10.8231, // TP. Hồ Chí Minh
        lng2: 106.6297,
      );
      // Giá trị tham chiếu tính bằng cùng công thức với R = 6 371 000 m.
      expect(d, closeTo(1137866.83, 1.0));
    });

    test('Hồ Hoàn Kiếm → Bệnh viện 103 (Trần Hữu Dực) ≈ 7 317 m', () {
      final double d = GeofenceService.haversineDistance(
        lat1: 21.0285, // Hồ Hoàn Kiếm
        lng1: 105.8542,
        lat2: 21.0289, // Bệnh viện 103 – Viện Quân y
        lng2: 105.7837,
      );
      expect(d, closeTo(7317.29, 1.0));
    });

    test('Hồng Kông → Ma Cao ≈ 65 751 m', () {
      final double d = GeofenceService.haversineDistance(
        lat1: 22.3193,
        lng1: 114.1694,
        lat2: 22.1987,
        lng2: 113.5439,
      );
      expect(d, closeTo(65751.42, 1.0));
    });

    test('cùng một điểm cho khoảng cách bằng 0', () {
      final double d = GeofenceService.haversineDistance(
        lat1: 21.0285,
        lng1: 105.8542,
        lat2: 21.0285,
        lng2: 105.8542,
      );
      expect(d, 0);
    });

    test('đối xứng: khoảng cách A→B bằng B→A', () {
      final double ab = GeofenceService.haversineDistance(
        lat1: 21.0285,
        lng1: 105.8542,
        lat2: 21.0441,
        lng2: 105.8482,
      );
      final double ba = GeofenceService.haversineDistance(
        lat1: 21.0441,
        lng1: 105.8482,
        lat2: 21.0285,
        lng2: 105.8542,
      );
      expect(ab, closeTo(ba, 1e-6));
    });

    test('Haversine khác xa khoảng cách Euclid phẳng ở vĩ độ cao', () {
      // Ở vĩ độ ~60°, 1° kinh độ theo vòng cung ngắn hơn nhiều so với
      // đường thẳng "phẳng" trên giấy — đây là lý do phải dùng Haversine.
      final double d = GeofenceService.haversineDistance(
        lat1: 60.0,
        lng1: 0.0,
        lat2: 60.0,
        lng2: 1.0,
      );
      // Giá trị tham chiếu: ~55 597 m (1° kinh độ tại vĩ độ 60°).
      expect(d, closeTo(55596.93, 1.0));

      // Khoảng cách "phẳng" (sai) theo mô hình Pythagoras trên mặt phẳng:
      final double flat = mathEuclid(60.0, 0.0, 60.0, 1.0);
      expect((d - flat).abs(), greaterThan(30000));
    });
  });

  group('Kiểm tra trạng thái trong / ngoài vùng', () {
    const home = Geofence(
      id: 'fence_home',
      name: 'Nhà riêng',
      centerLatitude: 21.0285,
      centerLongitude: 105.8542,
      radiusMeters: 100,
    );

    test('điểm ngay tâm vùng nằm trong vùng', () {
      final position = fakePosition(21.0285, 105.8542);
      expect(GeofenceService.checkGeofenceStatus(position, home), isTrue);
    });

    test('điểm cách ~93m về phía đông nằm trong vùng 100m', () {
      const offset = 0.000900;
      final position = fakePosition(21.0285, 105.8542 + offset);
      final double distance =
          GeofenceService.distanceToFence(LatLng(21.0285, 105.8542 + offset), home);
      expect(distance, closeTo(93.41, 0.5));
      expect(distance, lessThan(home.radiusMeters));
      expect(GeofenceService.checkGeofenceStatus(position, home), isTrue);
    });

    test('điểm cách ~100.3m về phía đông nằm NGOÀI vùng 100m', () {
      const offset = 0.000966;
      final position = fakePosition(21.0285, 105.8542 + offset);
      final double distance =
          GeofenceService.distanceToFence(LatLng(21.0285, 105.8542 + offset), home);
      expect(distance, closeTo(100.26, 0.5));
      expect(distance, greaterThan(home.radiusMeters));
      expect(GeofenceService.checkGeofenceStatus(position, home), isFalse);
    });

    test('điểm cách ~500m nằm ngoài vùng', () {
      final position = fakePosition(21.0285, 105.8542 + 0.004830);
      expect(GeofenceService.checkGeofenceStatus(position, home), isFalse);
    });

    test('biên: khoảng cách đúng bằng bán kính vẫn được coi là bên trong', () {
      // Dựng vùng có bán kính khớp chính xác khoảng cách đo được.
      const center = LatLng(21.0285, 105.8542);
      const offset = LatLng(21.0285, 105.8542 + 0.000966);
      final double distance = GeofenceService.distanceBetween(center, offset);
      final fence = home.copyWith(radiusMeters: distance);

      expect(
        GeofenceService.checkGeofenceStatus(
          fakePosition(offset.latitude, offset.longitude),
          fence,
        ),
        isTrue,
      );
    });

    test('vùng bị tắt vẫn xác định được vị trí nhưng không phát sự kiện', () {
      final disabled = home.copyWith(isEnabled: false);
      final transitions = GeofenceService.evaluateTransitions(
        currentPos: const LatLng(21.0285, 105.8542),
        fences: [disabled],
      );
      expect(transitions, isEmpty);
    });
  });

  group('Chuyển trạng thái ENTER / EXIT', () {
    const home = Geofence(
      id: 'fence_home',
      name: 'Nhà riêng',
      centerLatitude: 21.0285,
      centerLongitude: 105.8542,
      radiusMeters: 100,
    );

    test('từ ngoài vào trong phát sinh sự kiện ENTER', () {
      final transitions = GeofenceService.evaluateTransitions(
        currentPos: const LatLng(21.0285, 105.8542), // đang ở tâm vùng
        fences: [home], // isInside = false (trạng thái trước: ở ngoài)
      );

      expect(transitions.length, 1);
      expect(transitions.first.type, GeofenceTransitionType.enter);
      expect(transitions.first.isEnter, isTrue);
      expect(transitions.first.fence.id, 'fence_home');
      expect(transitions.first.distanceMeters, closeTo(0, 0.001));
    });

    test('từ trong ra ngoài phát sinh sự kiện EXIT', () {
      final inside = home.copyWith(isInside: true);
      final transitions = GeofenceService.evaluateTransitions(
        currentPos: const LatLng(21.0285, 105.8542 + 0.0100), // ~1km ra ngoài
        fences: [inside],
      );

      expect(transitions.length, 1);
      expect(transitions.first.type, GeofenceTransitionType.exit);
      expect(transitions.first.isExit, isTrue);
      expect(transitions.first.distanceMeters, greaterThan(100));
    });

    test('đứng yên trong vùng KHÔNG phát sinh sự kiện (chống spam)', () {
      final inside = home.copyWith(isInside: true);
      final transitions = GeofenceService.evaluateTransitions(
        currentPos: const LatLng(21.0285, 105.8542 + 0.0002), // vẫn trong vùng
        fences: [inside],
      );
      expect(transitions, isEmpty);
    });

    test('đứng yên ngoài vùng KHÔNG phát sinh sự kiện', () {
      final transitions = GeofenceService.evaluateTransitions(
        currentPos: const LatLng(21.0285, 105.8542 + 0.0100),
        fences: [home], // isInside = false
      );
      expect(transitions, isEmpty);
    });

    test('chuỗi ENTER → EXIT → ENTER được phát hiện đầy đủ', () {
      const outside = LatLng(21.0285, 105.8542 + 0.0100);
      const inside = LatLng(21.0285, 105.8542);

      // Lần 1: ngoài → trong.
      final first = GeofenceService.evaluateTransitions(
        currentPos: inside,
        fences: [home],
      );
      expect(first.single.type, GeofenceTransitionType.enter);

      // Commit trạng thái rồi đánh giá lại tại cùng vị trí: không có sự kiện.
      final committed = GeofenceService.updateFenceStatuses(
        currentPos: inside,
        fences: [home],
      );
      expect(committed.single.isInside, isTrue);
      expect(
        GeofenceService.evaluateTransitions(
          currentPos: inside,
          fences: committed,
        ),
        isEmpty,
      );

      // Lần 2: trong → ngoài.
      final second = GeofenceService.evaluateTransitions(
        currentPos: outside,
        fences: committed,
      );
      expect(second.single.type, GeofenceTransitionType.exit);

      // Lần 3: ngoài → trong lại.
      final committedAgain = GeofenceService.updateFenceStatuses(
        currentPos: outside,
        fences: committed,
      );
      final third = GeofenceService.evaluateTransitions(
        currentPos: inside,
        fences: committedAgain,
      );
      expect(third.single.type, GeofenceTransitionType.enter);
    });

    test('evaluateGeofenceUpdate trả về cả sự kiện lẫn vùng đã cập nhật', () {
      final update = GeofenceService.evaluateGeofenceUpdate(
        currentPos: const LatLng(21.0285, 105.8542),
        fences: [home],
      );
      expect(update.hasTransitions, isTrue);
      expect(update.transitions.single.isEnter, isTrue);
      expect(update.fences.single.isInside, isTrue);
    });

    test('nhiều vùng: chỉ vùng bị ảnh hưởng mới phát sự kiện', () {
      const work = Geofence(
        id: 'fence_work',
        name: 'Cơ quan',
        centerLatitude: 21.0289,
        centerLongitude: 105.7837,
        radiusMeters: 200,
      );

      final transitions = GeofenceService.evaluateTransitions(
        currentPos: const LatLng(21.0285, 105.8542),
        fences: [home, work],
      );

      expect(transitions.length, 1);
      expect(transitions.single.fence.id, 'fence_home');
      expect(transitions.single.isEnter, isTrue);
    });
  });

  group('Seed geofences', () {
    test('có 2 vùng mặc định với bán kính 100m và 200m', () {
      final fences = GeofenceService.seedGeofences();
      expect(fences.length, 2);
      expect(fences[0].name, 'Nhà riêng');
      expect(fences[0].radiusMeters, 100);
      expect(fences[1].name, 'Cơ quan / Trường học');
      expect(fences[1].radiusMeters, 200);
      expect(fences.every((f) => f.isEnabled), isTrue);
    });
  });
}

/// Khoảng cách Euclid "phẳng" (Pythagoras) — chỉ dùng để chứng minh Haversine
/// chính xác hơn. Dùng cùng thang độ như Haversine để so sánh công bằng.
double mathEuclid(double lat1, double lng1, double lat2, double lng2) {
  const double metersPerDegree = 111320.0;
  final double dLat = (lat2 - lat1) * metersPerDegree;
  final double dLng = (lng2 - lng1) * metersPerDegree;
  return math.sqrt(dLat * dLat + dLng * dLng);
}
