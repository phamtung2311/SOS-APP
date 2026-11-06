import 'package:latlong2/latlong.dart';

/// Mô tả một "vùng an toàn" (geofence) — hình tròn địa lý quanh một điểm
/// tọa độ với bán kính tính bằng mét.
///
/// Ví dụ: "Nhà riêng" bán kính 100m, "Cơ quan / Trường học" bán kính 200m.
class Geofence {
  const Geofence({
    required this.id,
    required this.name,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    this.isEnabled = true,
    this.isInside = false,
  });

  /// Mã định danh duy nhất của vùng.
  final String id;

  /// Tên hiển thị cho người dùng.
  final String name;

  /// Vĩ độ tâm vùng (độ).
  final double centerLatitude;

  /// Kinh độ tâm vùng (độ).
  final double centerLongitude;

  /// Bán kính vùng an toàn (mét).
  final double radiusMeters;

  /// Vùng có đang được bật hay không.
  final bool isEnabled;

  /// Trạng thái hiện tại của người dùng: đang ở trong (`true`) hay ở ngoài.
  ///
  /// Dùng để phát hiện chuyển trạng thái ENTER / EXIT mà không spam cảnh báo.
  final bool isInside;

  /// Tâm vùng dưới dạng [LatLng] để tiện dùng với `flutter_map`.
  LatLng get center => LatLng(centerLatitude, centerLongitude);

  Geofence copyWith({
    String? id,
    String? name,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusMeters,
    bool? isEnabled,
    bool? isInside,
  }) {
    return Geofence(
      id: id ?? this.id,
      name: name ?? this.name,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isEnabled: isEnabled ?? this.isEnabled,
      isInside: isInside ?? this.isInside,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'centerLatitude': centerLatitude,
        'centerLongitude': centerLongitude,
        'radiusMeters': radiusMeters,
        'isEnabled': isEnabled,
        'isInside': isInside,
      };

  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      centerLatitude: (json['centerLatitude'] as num?)?.toDouble() ?? 0.0,
      centerLongitude: (json['centerLongitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 0.0,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isInside: json['isInside'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'Geofence($id, $name, r=${radiusMeters}m, inside=$isInside)';
}
