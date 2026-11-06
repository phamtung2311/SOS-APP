import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sos_safe_family/data/models/sos_event.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';

/// Kết quả mã hóa một sự kiện SOS, sẵn sàng gửi đi.
class EncryptedSosPayload {
  const EncryptedSosPayload({
    required this.event,
    required this.encryptedEvent,
    required this.encryptedLocation,
  });

  /// Sự kiện gốc (chỉ giữ trong bộ nhớ, không đi kèm ra ngoài).
  final SosEvent event;

  /// Toàn bộ payload sự kiện đã mã hóa AES-256-GCM (base64).
  final String encryptedEvent;

  /// Tọa độ đã mã hóa AES-256-GCM (base64) — dùng `encryptLocationPayload`.
  final String encryptedLocation;

  /// Tổng payload gửi đi.
  Map<String, dynamic> toWireJson() => {
        'sosId': event.sosId,
        'encryptedEvent': encryptedEvent,
        'encryptedLocation': encryptedLocation,
      };
}

/// Dịch vụ đóng gói & mã hóa sự kiện SOS khẩn cấp.
///
/// Luồng: `SosEvent` → JSON → AES-256-GCM (nonce ngẫu nhiên 12 byte + MAC
/// 128 bit) → base64. Toạ độ gốc không bao giờ tồn tại trong payload gửi đi.
class SosService {
  SosService({CryptoService? cryptoService})
      : _crypto = cryptoService ?? CryptoService();

  final CryptoService _crypto;

  /// Mã hóa toàn bộ sự kiện SOS.
  ///
  /// [key] là khóa phiên 32 byte đã thỏa thuận qua ECDH X25519.
  Future<EncryptedSosPayload> encryptEvent({
    required SosEvent event,
    required Uint8List key,
  }) async {
    final secretKey = SecretKey(key);

    // 1) Mã hóa toàn bộ payload sự kiện.
    final encryptedEvent = await _crypto.encryptTextMessage(
      jsonEncode(event.toJson()),
      key,
    );

    // 2) Mã hóa riêng cặp toạ độ bằng API chuyên dụng.
    final encryptedLocation = await _crypto.encryptLocationPayload(
      lat: event.lat,
      lng: event.lng,
      key: secretKey,
    );

    return EncryptedSosPayload(
      event: event,
      // Định dạng vận chuyển: nonce(12) || mac(16) || ciphertext — giống
      // `encryptLocationPayload`, để bên nhận có thể giải mã độc lập.
      encryptedEvent: base64Encode(encryptedEvent.toTransportBytes()),
      encryptedLocation: encryptedLocation,
    );
  }
}
