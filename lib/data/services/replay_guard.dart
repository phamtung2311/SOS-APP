import 'package:sos_safe_family/core/constants.dart';

/// Kết quả kiểm tra chống phát lại (replay) cho một gói tin đã nhận.
enum ReplayVerdict {
  /// Gói tin hợp lệ: chưa từng thấy và còn trong thời hạn.
  accepted,

  /// Gói tin đã quá thời hạn (timestamp quá cũ).
  expired,

  /// Gói tin trùng nonce — tức đây là bản ghi lại của một gói tin đã nhận.
  duplicateNonce,
}

/// Bộ nhớ chống phát lại (anti-replay).
///
/// Chống hai kiểu tấn công điển hình:
///  * **Replay cũ** — gói tin cũ được gửi lại sau khi đã hết hạn
///    (`AppConstants.sosExpiresAfter`). Gói tin bị từ chối vì quá cũ.
///  * **Replay trùng nonce** — kẻ tấn công ghi lại đúng gói tin hợp lệ đã
///    gửi trước đó rồi phát lại. Nonce 96-bit ngẫu nhiên của AES-GCM giúp
///    phát hiện trùng lặp: mỗi nonce chỉ được chấp nhận đúng một lần.
///
/// Không trạng thái này được lưu lâu hơn [maxAge] — sau đó nonce cũ bị quên
/// để bộ nhớ không phình vô hạn.
class ReplayGuard {
  ReplayGuard({this.maxAge = AppConstants.sosExpiresAfter});

  /// Tuổi tối đa được chấp nhận của một gói tin.
  final Duration maxAge;

  final Set<String> _seenNonces = <String>{};
  final Map<String, DateTime> _seenAt = <String, DateTime>{};

  /// Đánh giá một gói tin đến.
  ///
  /// Nếu [verdict] là [ReplayVerdict.accepted] thì nonce được ghi nhớ để các
  /// lần gửi lại sau đó bị từ chối với [ReplayVerdict.duplicateNonce].
  ReplayVerdict check({
    required String nonceBase64,
    required DateTime timestamp,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();

    // Gói tin quá cũ -> hết hạn.
    if (current.difference(timestamp) > maxAge) {
      return ReplayVerdict.expired;
    }

    // Nonce đã từng thấy -> bản ghi lại.
    if (_seenNonces.contains(nonceBase64)) {
      return ReplayVerdict.duplicateNonce;
    }

    _seenNonces.add(nonceBase64);
    _seenAt[nonceBase64] = current;
    _prune(current);

    return ReplayVerdict.accepted;
  }

  /// Nonce này đã từng được chấp nhận hay chưa.
  bool hasSeen(String nonceBase64) => _seenNonces.contains(nonceBase64);

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

  @override
  String toString() => 'ReplayAttackException: gói tin bị từ chối ($verdict)';
}
