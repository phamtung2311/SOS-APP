import 'dart:convert';
import 'dart:typed_data';

import 'package:sos_safe_family/data/models/sos_event.dart';

/// Kết quả mã hóa một sự kiện SOS, sẵn sàng gửi đi.
///
/// Gồm 2 phần ciphertext (bắt buộc) và 1 phần metadata không nhạy cảm
/// ([sentAt]) dùng để chống phát lại *trước khi* tốn công giải mã.
class EncryptedSosPayload {
  const EncryptedSosPayload({
    required this.event,
    required this.encryptedEvent,
    required this.encryptedLocation,
    this.sentAt,
  });

  /// Sự kiện gốc (chỉ giữ trong bộ nhớ, không đi kèm ra ngoài).
  final SosEvent event;

  /// Toàn bộ payload sự kiện đã mã hóa AES-256-GCM (base64).
  final String encryptedEvent;

  /// Tọa độ đã mã hóa AES-256-GCM (base64) — dùng `encryptLocationPayload`.
  final String encryptedLocation;

  /// Thời điểm gửi gói tin (metadata **không mã hóa**).
  ///
  /// Chỉ dùng để lọc gói tin quá hạn trước khi giải mã. Không mang ý nghĩa
  /// bảo mật — kẻ tấn công có thể sửa nó, nhưng hậu quả chỉ giới hạn ở việc
  /// tự loại bỏ gói tin của chính mình, không ảnh hưởng người dùng hợp pháp.
  final DateTime? sentAt;

  /// Nonce 96-bit (12 byte) đầu tiên của gói tin, dạng Base64.
  ///
  /// Đây là "định danh duy nhất" của gói tin dùng để phát hiện phát lại.
  String get nonceBase64 {
    try {
      final Uint8List raw = base64Decode(encryptedEvent);
      if (raw.length < 12) return '';
      return base64Encode(raw.sublist(0, 12));
    } on FormatException {
      return '';
    }
  }

  /// Tổng payload gửi đi.
  Map<String, dynamic> toWireJson() => {
        'sosId': event.sosId,
        'encryptedEvent': encryptedEvent,
        'encryptedLocation': encryptedLocation,
        if (sentAt != null) 'sentAt': sentAt!.millisecondsSinceEpoch,
      };

  /// Khôi phục payload từ dạng wire (dùng khi nhận từ máy chủ).
  factory EncryptedSosPayload.fromWireJson(Map<String, dynamic> json) {
    return EncryptedSosPayload(
      // Sự kiện gốc không đi kèm trên đường truyền — bên nhận sẽ dựng lại
      // sau khi giải mã `encryptedEvent`.
      event: SosEvent.fromJson(const <String, dynamic>{}),
      encryptedEvent: json['encryptedEvent'] as String? ?? '',
      encryptedLocation: json['encryptedLocation'] as String? ?? '',
      sentAt: json['sentAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['sentAt'] as num).toInt(),
            ),
    );
  }
}
