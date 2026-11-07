import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sos_safe_family/data/models/encrypted_sos_payload.dart';
import 'package:sos_safe_family/data/models/sos_event.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/replay_guard.dart';

/// Dịch vụ đóng gói & mã hóa sự kiện SOS khẩn cấp.
///
/// Luồng: `SosEvent` → JSON → AES-256-GCM (nonce ngẫu nhiên 12 byte + MAC
/// 128 bit) → base64. Toạ độ gốc không bao giờ tồn tại trong payload gửi đi.
class SosService {
  SosService({CryptoService? cryptoService, ReplayGuard? replayGuard})
      : _crypto = cryptoService ?? CryptoService(),
        _replayGuard = replayGuard ?? ReplayGuard();

  final CryptoService _crypto;

  /// Bộ nhớ chống phát lại dùng chung cho mọi gói tin đến.
  final ReplayGuard _replayGuard;

  /// Bộ nhớ chống phát lại (để lớp trên có thể theo dõi / reset nếu cần).
  ReplayGuard get replayGuard => _replayGuard;

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
      sentAt: DateTime.now(),
    );
  }

  /// Xử lý một gói tin SOS **đến** — điểm kiểm soát chống tấn công.
  ///
  /// Thứ tự kiểm tra là **cố ý** sắp xếp theo chi phí tăng dần:
  ///
  ///  1. **[ReplayGuard.evaluate]** — kiểm tra Nonce Registry và thời hạn
  ///     *trước khi giải mã*. Nếu gói tin bị phát lại (nonce trùng) hoặc quá
  ///     hạn, hàm ném [ReplayAttackException] **ngay lập tức** — không tốn
  ///     công giải mã, vừa chặn spam vừa bảo vệ CPU.
  ///  2. **Giải mã AES-256-GCM** — AEAD tự kiểm tra MAC; gói tin bị can thiệp
  ///     sẽ ném `SecretBoxAuthenticationError`.
  ///  3. **Đối chiếu timestamp** trong ciphertext đã xác thực với thời điểm
  ///     nhận, để chặn trường hợp `sentAt` trên wire bị kẻ tấn công sửa.
  ///
  /// Trả về [SosEvent] đã giải mã khi gói tin hợp lệ.
  Future<SosEvent> handleIncomingSos({
    required EncryptedSosPayload encryptedPayload,
    required SecretKey sharedKey,
    DateTime? receiveTime,
  }) async {
    final DateTime now = receiveTime ?? DateTime.now();

    // (1) Chống phát lại — trước khi giải mã.
    final ReplayVerdict verdict = _replayGuard.evaluate(
      encryptedPayload,
      now: now,
    );
    if (verdict != ReplayVerdict.accepted) {
      throw ReplayAttackException(verdict);
    }

    // (2) Giải mã payload sự kiện — AEAD kiểm tra MAC.
    final EncryptedPayload wire = EncryptedPayload.fromTransportBytes(
      base64Decode(encryptedPayload.encryptedEvent),
    );
    final Uint8List keyBytes = Uint8List.fromList(await sharedKey.extractBytes());
    final String plaintext = await _crypto.decryptTextMessage(wire, keyBytes);
    final Object? decoded = jsonDecode(plaintext);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Decoded SOS payload is not a JSON object.');
    }
    final SosEvent event = SosEvent.fromJson(decoded);

    // (3) Đối chiếu timestamp đã xác thực (nằm trong ciphertext) với thời
    // điểm nhận — không tin `sentAt` trên wire.
    if (now.difference(event.timestamp) > _replayGuard.maxAge) {
      throw const ReplayAttackException(ReplayVerdict.expired);
    }

    // Giải mã toạ độ để bên nhận hiển thị / kích hoạt cảnh báo.
    final Map<String, dynamic> location =
        await _crypto.decryptLocationPayload(
      encryptedBase64: encryptedPayload.encryptedLocation,
      key: sharedKey,
    );

    return event.copyWith(
      lat: (location['lat'] as num?)?.toDouble() ?? event.lat,
      lng: (location['lng'] as num?)?.toDouble() ?? event.lng,
    );
  }

  /// Nhận & xác thực một gói tin SOS đến từ máy chủ / thành viên khác.
  ///
  /// Phiên bản gọn gàng dựa trên [handleIncomingSos], nhận trực tiếp hai
  /// chuỗi ciphertext từ dạng wire thay vì đối tượng [EncryptedSosPayload].
  Future<SosEvent> receiveSos({
    required String encryptedEventBase64,
    required String encryptedLocationBase64,
    required Uint8List key,
    DateTime? now,
  }) async {
    return handleIncomingSos(
      encryptedPayload: EncryptedSosPayload(
        event: SosEvent.fromJson(const <String, dynamic>{}),
        encryptedEvent: encryptedEventBase64,
        encryptedLocation: encryptedLocationBase64,
        // `sentAt` không nằm trong ciphertext — dùng thời điểm nhận như
        // mốc tham chiếu; bước (3) của `handleIncomingSos` sẽ đối chiếu
        // timestamp đã xác thực bên trong payload.
        sentAt: now,
      ),
      sharedKey: SecretKey(key),
      receiveTime: now,
    );
  }
}
