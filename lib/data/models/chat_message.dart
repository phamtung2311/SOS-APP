import 'dart:typed_data';

/// Loại nội dung của một tin nhắn.
enum MessageType { text, image }

/// Một tin nhắn trong khung chat E2EE.
///
/// Vòng đời dữ liệu của một tin nhắn:
///   plaintext (chỉ ở RAM/cục bộ)  →  ciphertext (đi qua đường truyền)
///   →  giải mã ở thiết bị nhận  →  plaintext hiển thị.
///
/// [plaintext] và [decryptedImageBytes] **không bao giờ** được gửi lên mạng;
/// chúng chỉ tồn tại trong bộ nhớ của thiết bị.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.type,
    this.plaintext,
    this.ciphertextBase64,
    this.nonceBase64,
    this.macBase64,
    this.localImagePath,
    this.decryptedImageBytes,
    this.isEncrypted = true,
  });

  /// UUID định danh tin nhắn.
  final String id;

  /// 'me' nếu do chính người dùng gửi, 'other' nếu do thành viên khác gửi.
  final String senderId;

  /// Tên hiển thị của người gửi (ví dụ: "Tôi", "Bố", "Mẹ").
  final String senderName;

  final DateTime timestamp;
  final MessageType type;

  /// Văn bản gốc — chỉ lưu ở máy cục bộ, không đưa lên đường truyền.
  final String? plaintext;

  /// Bản mã Base64 — đây mới là dữ liệu "đi trên mạng".
  final String? ciphertextBase64;

  /// Nonce 96-bit dạng Base64.
  final String? nonceBase64;

  /// Authentication tag (MAC) 128-bit dạng Base64.
  final String? macBase64;

  /// Đường dẫn file ảnh trên thiết bị (dành cho tin nhắn ảnh).
  final String? localImagePath;

  /// Dữ liệu ảnh sau khi giải mã — sẵn sàng hiển thị trên giao diện.
  final Uint8List? decryptedImageBytes;

  /// Cờ cho biết tin nhắn đã được mã hóa E2EE.
  final bool isEncrypted;

  bool get isMine => senderId == 'me';

  /// Rút gọn ciphertext để hiển thị trong Crypto Inspector.
  String get shortCiphertext {
    final c = ciphertextBase64 ?? '';
    if (c.length <= 48) return c;
    return '${c.substring(0, 24)}\n...\n${c.substring(c.length - 24)}';
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    DateTime? timestamp,
    MessageType? type,
    String? plaintext,
    String? ciphertextBase64,
    String? nonceBase64,
    String? macBase64,
    String? localImagePath,
    Uint8List? decryptedImageBytes,
    bool? isEncrypted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      plaintext: plaintext ?? this.plaintext,
      ciphertextBase64: ciphertextBase64 ?? this.ciphertextBase64,
      nonceBase64: nonceBase64 ?? this.nonceBase64,
      macBase64: macBase64 ?? this.macBase64,
      localImagePath: localImagePath ?? this.localImagePath,
      decryptedImageBytes: decryptedImageBytes ?? this.decryptedImageBytes,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }
}
