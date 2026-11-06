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
}

class CryptoService {
  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Random _random = Random.secure();

  Future<SimpleKeyPair> generateKeyPairX25519() async {
    return _x25519.newKeyPair();
  }

  Future<String> exportPublicKey(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
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
