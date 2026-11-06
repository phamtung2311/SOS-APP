import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';

/// Một phiên chia sẻ hành trình bảo mật bằng mã 6 chữ số.
///
/// Mã gốc chỉ tồn tại trong RAM và được hiển thị cho người dùng; những gì
/// được lưu/truyền đi là **chuỗi băm SHA-256** của mã. Nhờ vậy kẻ trung gian
/// (kể cả người chặn đường truyền) không thể suy ra mã gốc từ dữ liệu bị lộ.
class TripShare {
  const TripShare({
    required this.codeHash,
    required this.createdAt,
    required this.expiresAt,
    this.tripId,
  });

  /// Chuỗi băm SHA-256 (hex) của mã 6 chữ số.
  final String codeHash;

  /// Thời điểm tạo phiên chia sẻ.
  final DateTime createdAt;

  /// Thời điểm hết hạn (TTL 60 phút kể từ [createdAt]).
  final DateTime expiresAt;

  /// Định danh chuyến đi (tuỳ chọn).
  final String? tripId;

  /// Còn hiệu lực hay không, tính tại thời điểm [now].
  bool isValidAt(DateTime now) => now.isBefore(expiresAt);

  /// Số giây còn lại trước khi hết hạn (>= 0).
  int remainingSecondsAt(DateTime now) {
    final int s = expiresAt.difference(now).inSeconds;
    return s < 0 ? 0 : s;
  }

  Map<String, dynamic> toJson() => {
        'codeHash': codeHash,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        if (tripId != null) 'tripId': tripId,
      };

  factory TripShare.fromJson(Map<String, dynamic> json) {
    return TripShare(
      codeHash: json['codeHash'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      tripId: json['tripId'] as String?,
    );
  }
}

/// Dịch vụ sinh & kiểm tra mã chia sẻ hành trình 6 chữ số.
///
/// Mã được sinh bằng `Random.secure()` (CSPRNG của hệ điều hành), băm bằng
/// SHA-256 trước khi lưu/truyền tin, và tự hủy sau [defaultTtl].
class TripShareService {
  TripShareService({CryptoService? cryptoService})
      : _crypto = cryptoService ?? CryptoService();

  final CryptoService _crypto;

  /// Số chữ số của mã chia sẻ.
  static const int codeLength = 6;

  /// Thời gian tự hủy (TTL) — 60 phút.
  static const Duration defaultTtl = Duration(minutes: 60);

  final Random _random = Random.secure();

  /// Sinh mã 6 chữ số ngẫu nhiên.
  ///
  /// Dùng `Random.secure()` — nguồn ngẫu nhiên phần cứng của hệ điều hành.
  String generateCode() {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < codeLength; i++) {
      buffer.write(_random.nextInt(10));
    }
    return buffer.toString();
  }

  /// Băm SHA-256 một chuỗi bất kỳ, trả về chuỗi hex.
  Future<String> hashTripCode(String code) async {
    final Hash digest = await _crypto.sha256Hash(code);
    return digest.bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Tạo một phiên chia sẻ hành trình mới.
  ///
  /// Trả về cặp `[code, tripShare]`: [code] là mã gốc chỉ hiển thị một lần cho
  /// người dùng, [TripShare.codeHash] là thứ được lưu/truyền đi.
  Future<(String, TripShare)> createTripShare({
    DateTime? now,
    Duration? ttl,
    String? tripId,
  }) async {
    final DateTime created = now ?? DateTime.now();
    final Duration effectiveTtl = ttl ?? defaultTtl;
    final String code = generateCode();
    final String hash = await hashTripCode(code);

    final TripShare share = TripShare(
      codeHash: hash,
      createdAt: created,
      expiresAt: created.add(effectiveTtl),
      tripId: tripId,
    );

    return (code, share);
  }

  /// Kiểm tra một mã người dùng nhập có khớp với phiên chia sẻ hay không.
  ///
  /// Trả về `false` nếu phiên đã hết hạn.
  Future<bool> verifyCode({
    required String code,
    required TripShare share,
    DateTime? now,
  }) async {
    final DateTime checked = now ?? DateTime.now();
    if (!share.isValidAt(checked)) return false;

    final String hash = await hashTripCode(code);
    return hash == share.codeHash;
  }
}
