import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Dữ liệu mã hóa chuẩn (gồm ciphertext, nonce, mac) — dùng chung cho
/// tin nhắn văn bản và dữ liệu nhị phân (ảnh).
class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
  });

  /// Dữ liệu đã mã hóa (AES-256-GCM).
  final Uint8List ciphertext;

  /// Nonce 96-bit (12 byte) ngẫu nhiên.
  final Uint8List nonce;

  /// Authentication tag (MAC) 128-bit (16 byte).
  final Uint8List mac;

  String get ciphertextBase64 => base64Encode(ciphertext);
  String get nonceBase64 => base64Encode(nonce);
  String get macBase64 => base64Encode(mac);

  /// Ghép nonce || mac || ciphertext (định dạng 28 byte header).
  Uint8List toTransportBytes() {
    final out = Uint8List(nonce.length + mac.length + ciphertext.length);
    out.setAll(0, nonce);
    out.setAll(12, mac);
    out.setAll(28, ciphertext);
    return out;
  }

  factory EncryptedPayload.fromTransportBytes(Uint8List data) {
    if (data.length < 28) {
      throw const FormatException('Encrypted payload is too short.');
    }
    return EncryptedPayload(
      nonce: Uint8List.fromList(data.sublist(0, 12)),
      mac: Uint8List.fromList(data.sublist(12, 28)),
      ciphertext: Uint8List.fromList(data.sublist(28)),
    );
  }

  factory EncryptedPayload.fromBase64({
    required String ciphertextBase64,
    required String nonceBase64,
    required String macBase64,
  }) {
    return EncryptedPayload(
      ciphertext: Uint8List.fromList(base64Decode(ciphertextBase64)),
      nonce: Uint8List.fromList(base64Decode(nonceBase64)),
      mac: Uint8List.fromList(base64Decode(macBase64)),
    );
  }
}

class CryptoService {
  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Sha256 _sha256 = Sha256();
  final Random _random = Random.secure();

  /// Băm SHA-256 một chuỗi văn bản.
  ///
  /// Dùng để băm mã chia sẻ hành trình 6 chữ số trước khi lưu/truyền tin —
  /// kẻ trung gian không thể suy ra mã gốc từ chuỗi băm.
  Future<Hash> sha256Hash(String input) {
    return _sha256.hash(utf8.encode(input));
  }

  Future<SimpleKeyPair> generateKeyPairX25519() async {
    return _x25519.newKeyPair();
  }

  Future<String> exportPublicKey(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Trích xuất Private Key (32 byte) thành chuỗi Base64 để lưu vào Android Keystore.
  Future<String> exportPrivateKey(SimpleKeyPair keyPair) async {
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    return base64Encode(privateKeyBytes);
  }

  /// Tái tạo cặp khóa SimpleKeyPair từ chuỗi Base64 đã lưu trong Android Keystore.
  Future<SimpleKeyPair> importKeyPair({
    required String privateKeyB64,
    required String publicKeyB64,
  }) async {
    final privBytes = base64Decode(privateKeyB64);
    final pubBytes = base64Decode(publicKeyB64);
    return SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
  }

  /// Tính mã vân tay an toàn SHA-256 (Security Fingerprint) của Khóa công khai.
  ///
  /// Định dạng 8 cụm hex (ví dụ: `A1:B2:C3:D4:E5:F6:07:88`) dùng cho việc
  /// đối soát khóa ngoài băng tần (Out-of-band verification) giữa 2 người thân.
  Future<String> getPublicKeyFingerprint(String publicKeyB64) async {
    final pubBytes = base64Decode(publicKeyB64);
    final hash = await _sha256.hash(pubBytes);
    return hash.bytes
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  Future<SimplePublicKey> importPublicKey(String base64Key) async {
    final keyBytes = base64Decode(base64Key);
    if (keyBytes.length != 32) {
      throw const FormatException('Invalid X25519 public key length.');
    }
    return SimplePublicKey(keyBytes, type: KeyPairType.x25519);
  }

  Future<SecretKey> deriveSharedKey({
    required SimpleKeyPair myKeyPair,
    required SimplePublicKey theirPublicKey,
  }) async {
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: theirPublicKey,
    );

    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: Uint8List(32), // Chuẩn RFC 5869: salt mặc định 32 byte 0 cho SHA-256 (tránh Empty key trên Android JCE)
      info: utf8.encode('sos_safe_family_aes_key'),
    );
  }

  /// Dẫn xuất khóa phiên 32-byte (AES-256) chuẩn cho một phòng chat định danh.
  /// Đảm bảo hai bên cùng tham gia phòng chat đều tính ra đúng cùng một khóa phiên
  /// để mã hóa và giải mã E2EE qua lại thành công.
  Future<Uint8List> deriveRoomKey(String roomId) async {
    final bytes = utf8.encode('sos_chat_room_key_salt_$roomId');
    final hash = await Sha256().hash(bytes);
    return Uint8List.fromList(hash.bytes);
  }

  /// Dẫn xuất khóa phiên E2EE 32-byte (AES-256) giữa 2 người dùng qua ECDH X25519 + HKDF-SHA256.
  ///
  /// Thỏa thuận khóa Diffie-Hellman:
  /// - Người A: myKeyPair = keyPairA, theirPublicKeyB64 = publicKeyB
  /// - Người B: myKeyPair = keyPairB, theirPublicKeyB64 = publicKeyA
  /// Cả hai bên đều tính ra cùng một khóa phiên AES-256 (32 bytes) dùng cho phòng chat E2EE.
  Future<Uint8List> deriveChatKeyForPeer({
    required SimpleKeyPair myKeyPair,
    required String theirPublicKeyB64,
  }) async {
    final theirPublicKey = await importPublicKey(theirPublicKeyB64);
    final secretKey = await deriveSharedKey(
      myKeyPair: myKeyPair,
      theirPublicKey: theirPublicKey,
    );
    final keyBytes = await secretKey.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  /// Dẫn xuất khóa phiên E2EE từ private key và public key dạng Base64 lưu trong Keystore.
  Future<Uint8List> deriveChatKeyFromB64({
    required String myPrivateKeyB64,
    required String myPublicKeyB64,
    required String theirPublicKeyB64,
  }) async {
    final myKeyPair = await importKeyPair(
      privateKeyB64: myPrivateKeyB64,
      publicKeyB64: myPublicKeyB64,
    );
    return deriveChatKeyForPeer(
      myKeyPair: myKeyPair,
      theirPublicKeyB64: theirPublicKeyB64,
    );
  }

  Future<String> encryptLocationPayload({
    required double lat,
    required double lng,
    required SecretKey key,
  }) async {
    final payload = {
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final plaintext = utf8.encode(jsonEncode(payload));
    final nonce = _generateNonce();
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );

    final output = Uint8List(12 + 16 + secretBox.cipherText.length);
    output.setAll(0, nonce);
    output.setAll(12, secretBox.mac.bytes);
    output.setAll(28, secretBox.cipherText);

    return base64Encode(output);
  }

  Future<Map<String, dynamic>> decryptLocationPayload({
    required String encryptedBase64,
    required SecretKey key,
  }) async {
    final data = base64Decode(encryptedBase64);
    if (data.length < 28) {
      throw const FormatException('Encrypted payload is too short.');
    }

    final nonce = data.sublist(0, 12);
    final mac = Mac(data.sublist(12, 28));
    final ciphertext = data.sublist(28);

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: mac,
    );

    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: key,
    );

    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Decoded payload is not a JSON object.');
    }

    return decoded;
  }

  // ---------------------------------------------------------------------
  // Mã hóa tin nhắn văn bản & dữ liệu nhị phân (E2EE chat)
  // ---------------------------------------------------------------------

  /// Mã hóa văn bản bằng AES-256-GCM.
  ///
  /// [sharedKey] là 32 byte khóa phiên đã thỏa thuận qua ECDH X25519.
  /// Nonce 12 byte được sinh ngẫu nhiên cho **mỗi lần** gọi — tuyệt đối
  /// không tái sử dụng nonce với cùng một khóa.
  Future<EncryptedPayload> encryptTextMessage(
    String plaintext,
    Uint8List sharedKey,
  ) {
    return encryptMediaBytes(Uint8List.fromList(utf8.encode(plaintext)), sharedKey);
  }

  /// Giải mã văn bản. Ném [SecretBoxAuthenticationError] nếu MAC sai
  /// (tức dữ liệu bị can thiệp hoặc dùng sai khóa).
  Future<String> decryptTextMessage(
    EncryptedPayload payload,
    Uint8List sharedKey,
  ) async {
    final plain = await decryptMediaBytes(payload, sharedKey);
    return utf8.decode(plain);
  }

  /// Mã hóa dữ liệu nhị phân (ví dụ bytes của file ảnh) bằng AES-256-GCM.
  Future<EncryptedPayload> encryptMediaBytes(
    Uint8List rawBytes,
    Uint8List sharedKey,
  ) async {
    final nonce = _generateNonce();
    final secretBox = await _aesGcm.encrypt(
      rawBytes,
      secretKey: SecretKey(sharedKey),
      nonce: nonce,
    );
    return EncryptedPayload(
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      nonce: nonce,
      mac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  /// Giải mã dữ liệu nhị phân đã mã hóa.
  Future<Uint8List> decryptMediaBytes(
    EncryptedPayload payload,
    Uint8List sharedKey,
  ) async {
    final secretBox = SecretBox(
      payload.ciphertext,
      nonce: payload.nonce,
      mac: Mac(payload.mac),
    );
    final plain = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(sharedKey),
    );
    return Uint8List.fromList(plain);
  }

  Uint8List _generateNonce() {
    final nonce = Uint8List(12);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = _random.nextInt(256);
    }
    return nonce;
  }
}
