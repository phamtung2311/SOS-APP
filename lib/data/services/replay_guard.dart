import 'package:sos_safe_family/core/constants.dart';
import 'package:sos_safe_family/data/models/encrypted_sos_payload.dart';

/// Kết quả kiểm tra chống phát lại (replay) cho một gói tin đã nhận.
enum ReplayVerdict {
  /// Gói tin hợp lệ: chưa từng thấy và còn trong thời hạn.
  accepted,

  /// Gói tin đã quá thời hạn (timestamp quá cũ).
  expired,

  /// Gói tin trùng nonce — tức đây là bản ghi lại của một gói tin đã nhận.
  duplicateNonce,
}

/// Bộ nhớ chống phát lại (anti-replay) — Nonce Registry.
///
/// Chống hai kiểu tấn công điển hình:
///
///  * **Replay cũ** — gói tin cũ được gửi lại sau khi đã hết hạn
///    (`AppConstants.sosExpiresAfter`, mặc định 30 phút). Gói tin bị từ chối
///    vì quá cũ.
///  * **Replay trùng nonce** — kẻ tấn công ghi lại đúng gói tin hợp lệ đã
///    gửi trước đó rồi phát lại. Nonce 96-bit ngẫu nhiên của AES-GCM giúp
///    phát hiện trùng lặp: mỗi nonce chỉ được chấp nhận đúng một lần.
///
/// Nonce được ghi nhớ trong RAM và tự động bị quên sau [maxAge] để bộ nhớ
/// không phình vô hạn.
class ReplayGuard {
  ReplayGuard({this.maxAge = AppConstants.sosExpiresAfter});

  /// Tuổi tối đa được chấp nhận của một gói tin.
  final Duration maxAge;

  /// Nonce Registry — tập nonce đã được chấp nhận.
  final Set<String> _seenNonces = <String>{};

  /// Thời điểm từng nonce được chấp nhận (dùng để dọn bộ nhớ).
  final Map<String, DateTime> _seenAt = <String, DateTime>{};

  /// Đánh giá một gói tin SOS đến.
  ///
  /// Trả về [ReplayVerdict.accepted] nếu gói tin hợp lệ — khi đó nonce được
  /// ghi vào Nonce Registry để các lần gửi lại sau đó bị từ chối bằng
  /// [ReplayVerdict.duplicateNonce].
  ///
  /// [now] dùng cho việc kiểm thử theo thời gian giả lập; mặc định là thời
  /// điểm hiện tại.
  ReplayVerdict evaluate(
    EncryptedSosPayload payload, {
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();
    final String nonce = payload.nonceBase64;

    // Gói tin thiếu nonce hợp lệ -> không thể xác thực -> từ chối.
    if (nonce.isEmpty) {
      return ReplayVerdict.expired;
    }

    // (1) Nonce đã từng thấy -> bản ghi lại (replay).
    if (_seenNonces.contains(nonce)) {
      return ReplayVerdict.duplicateNonce;
    }

    // (2) Gói tin quá cũ -> hết hạn.
    //
    // `sentAt` trên wire là metadata không mã hóa nên không đáng tin tuyệt đối;
    // timestamp đã xác thực nằm trong ciphertext sẽ được đối chiếu thêm ở
    // bước giải mã. Khi không có mốc thời gian nào đáng tin, bỏ qua bước này
    // (gói tin vẫn bị chặn bởi kiểm tra timestamp đã xác thực).
    final DateTime? sentAt = payload.sentAt ?? _authenticTimestamp(payload);
    if (sentAt != null && current.difference(sentAt) > maxAge) {
      return ReplayVerdict.expired;
    }

    _seenNonces.add(nonce);
    _seenAt[nonce] = current;
    _prune(current);

    return ReplayVerdict.accepted;
  }

  /// Đánh giá một gói tin bằng nonce & timestamp thô (API cấp thấp).
  ///
  /// Dùng cho các luồng không có [EncryptedSosPayload] hoàn chỉnh.
  ReplayVerdict check({
    required String nonceBase64,
    required DateTime timestamp,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();

    if (current.difference(timestamp) > maxAge) {
      return ReplayVerdict.expired;
    }

    if (_seenNonces.contains(nonceBase64)) {
      return ReplayVerdict.duplicateNonce;
    }

    _seenNonces.add(nonceBase64);
    _seenAt[nonceBase64] = current;
    _prune(current);

    return ReplayVerdict.accepted;
  }

  /// Timestamp của sự kiện nếu sự kiện gốc đã được biết (không phải bản
  /// giải mã từ ciphertext).
  ///
  /// Trả về `null` khi sự kiện gốc là bản "placeholder" (chưa giải mã), tức
  /// không có timestamp đáng tin — khi đó bước kiểm tra tuổi gói tin ở tầng
  /// wire được bỏ qua và thay bằng kiểm tra timestamp đã xác thực.
  DateTime? _authenticTimestamp(EncryptedSosPayload payload) {
    final int ms = payload.event.timestamp.millisecondsSinceEpoch;
    if (ms <= 0) return null;
    return payload.event.timestamp;
  }

  /// Nonce này đã từng được chấp nhận hay chưa.
  bool hasSeen(String nonceBase64) => _seenNonces.contains(nonceBase64);

  /// Số lượng nonce đang được ghi nhớ (dùng cho chẩn đoán & kiểm thử).
  int get trackedNonceCount => _seenNonces.length;

  /// Xoá các nonce đã cũ hơn [maxAge] để bộ nhớ không phình vô hạn.
  void _prune(DateTime now) {
    final List<String> expired = <String>[];
    _seenAt.forEach((String nonce, DateTime at) {
      if (now.difference(at) > maxAge) expired.add(nonce);
    });
    for (final String nonce in expired) {
      _seenAt.remove(nonce);
      _seenNonces.remove(nonce);
    }
  }
}

/// Ngoại lệ ném ra khi phát hiện gói tin phát lại (replay).
class ReplayAttackException implements Exception {
  const ReplayAttackException(this.verdict);

  /// Lý do bị từ chối.
  final ReplayVerdict verdict;

  /// Thông điệp mô tả lý do, dùng để ghi vào nhật ký kiểm toán.
  String get reason => switch (verdict) {
        ReplayVerdict.expired => 'gói tin quá hạn',
        ReplayVerdict.duplicateNonce => 'nonce trùng (gói tin bị phát lại)',
        ReplayVerdict.accepted => 'không xác định',
      };

  @override
  String toString() => 'ReplayAttackException: gói tin bị từ chối ($reason)';
}
