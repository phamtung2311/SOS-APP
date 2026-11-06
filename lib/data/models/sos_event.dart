/// Trạng thái của một sự kiện SOS.
enum SosStatus {
  /// Cảnh báo đang hoạt động — người dùng chưa xác nhận an toàn.
  active,

  /// Người dùng đã bấm "TÔI ĐÃ AN TOÀN" — sự kiện kết thúc.
  resolved,
}

/// Tên chuỗi tương ứng với [SosStatus], dùng khi đóng gói payload.
extension SosStatusX on SosStatus {
  String get wireName => switch (this) {
        SosStatus.active => 'ACTIVE',
        SosStatus.resolved => 'RESOLVED',
      };

  static SosStatus fromWireName(String value) {
    return switch (value.toUpperCase()) {
      'ACTIVE' => SosStatus.active,
      'RESOLVED' => SosStatus.resolved,
      _ => SosStatus.active,
    };
  }
}

/// Mô tả một sự kiện SOS khẩn cấp do người dùng kích hoạt.
///
/// Payload được đóng gói dạng JSON rồi mã hóa AES-256-GCM trước khi gửi —
/// tọa độ gốc **không bao giờ** xuất hiện dạng plaintext trên đường truyền.
class SosEvent {
  const SosEvent({
    required this.sosId,
    required this.senderName,
    required this.lat,
    required this.lng,
    required this.isMocked,
    required this.batteryLevel,
    required this.timestamp,
    this.status = SosStatus.active,
    this.resolvedAt,
  });

  /// Mã định danh sự kiện SOS.
  final String sosId;

  /// Tên người gửi (chủ thiết bị).
  final String senderName;

  /// Vĩ độ lúc kích hoạt.
  final double lat;

  /// Kinh độ lúc kích hoạt.
  final double lng;

  /// Vị trí có bị phát hiện là GPS giả mạo hay không.
  final bool isMocked;

  /// Mức pin (0–100) tại thời điểm kích hoạt.
  final int batteryLevel;

  /// Thời điểm kích hoạt sự kiện.
  final DateTime timestamp;

  /// Trạng thái hiện tại của sự kiện.
  final SosStatus status;

  /// Thời điểm người dùng xác nhận an toàn (chỉ có khi [status] là resolved).
  final DateTime? resolvedAt;

  bool get isActive => status == SosStatus.active;
  bool get isResolved => status == SosStatus.resolved;

  /// Đóng gói sự kiện thành payload JSON để mã hóa.
  ///
  /// Khóa: `sosId`, `senderName`, `lat`, `lng`, `isMocked`, `batteryLevel`,
  /// `timestamp`, `status`.
  Map<String, dynamic> toJson() => {
        'sosId': sosId,
        'senderName': senderName,
        'lat': lat,
        'lng': lng,
        'isMocked': isMocked,
        'batteryLevel': batteryLevel,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.wireName,
        if (resolvedAt != null)
          'resolvedAt': resolvedAt!.millisecondsSinceEpoch,
      };

  factory SosEvent.fromJson(Map<String, dynamic> json) {
    return SosEvent(
      sosId: json['sosId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      isMocked: json['isMocked'] as bool? ?? false,
      batteryLevel: (json['batteryLevel'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as num?)?.toInt() ?? 0,
      ),
      status: SosStatusX.fromWireName(json['status'] as String? ?? 'ACTIVE'),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['resolvedAt'] as num).toInt(),
            ),
    );
  }

  /// Chuyển sự kiện sang trạng thái `RESOLVED` (người dùng đã an toàn).
  ///
  /// Trả về bản sao mới; trạng thái cũ không bị thay đổi.
  SosEvent resolve({DateTime? at}) {
    final resolvedTime = at ?? DateTime.now();
    return copyWith(
      status: SosStatus.resolved,
      resolvedAt: resolvedTime,
    );
  }

  SosEvent copyWith({
    String? sosId,
    String? senderName,
    double? lat,
    double? lng,
    bool? isMocked,
    int? batteryLevel,
    DateTime? timestamp,
    SosStatus? status,
    DateTime? resolvedAt,
  }) {
    return SosEvent(
      sosId: sosId ?? this.sosId,
      senderName: senderName ?? this.senderName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isMocked: isMocked ?? this.isMocked,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  String toString() =>
      'SosEvent($sosId, $senderName, ${status.wireName})';
}
