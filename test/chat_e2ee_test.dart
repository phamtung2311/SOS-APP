import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/data/models/chat_message.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';

void main() {
  group('E2EE chat encryption', () {
    late CryptoService service;
    late Uint8List key;

    setUp(() async {
      service = CryptoService();
      final alice = await service.generateKeyPairX25519();
      final bob = await service.generateKeyPairX25519();
      final shared = await service.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await service.importPublicKey(
          await service.exportPublicKey(bob),
        ),
      );
      key = Uint8List.fromList(await shared.extractBytes());
    });

    test('text message round-trip returns the original plaintext', () async {
      const original = 'Con ơi, con về nhà chưa?';
      final payload = await service.encryptTextMessage(original, key);
      final decrypted = await service.decryptTextMessage(payload, key);
      expect(decrypted, original);
    });

    test('ciphertext does not leak the plaintext', () async {
      const original = 'Mật khẩu là 123456';
      final payload = await service.encryptTextMessage(original, key);
      final raw = String.fromCharCodes(payload.ciphertext);
      expect(raw.contains(original), isFalse);
    });

    test('nonce is 12 bytes and mac is 16 bytes', () async {
      final payload = await service.encryptTextMessage('xin chào', key);
      expect(payload.nonce.length, 12);
      expect(payload.mac.length, 16);
    });

    test('same plaintext encrypts to different ciphertext each time', () async {
      final results = <String>{};
      for (var i = 0; i < 50; i++) {
        final p = await service.encryptTextMessage('nội dung', key);
        results.add(p.ciphertextBase64);
      }
      expect(results.length, 50);
    });

    test('media bytes round-trip preserves binary data', () async {
      final image = Uint8List.fromList(
        List<int>.generate(4096, (i) => i % 256),
      );
      final payload = await service.encryptMediaBytes(image, key);
      final decrypted = await service.decryptMediaBytes(payload, key);
      expect(decrypted, equals(image));
    });

    test('tampered ciphertext fails authentication', () async {
      final payload = await service.encryptTextMessage('nội dung', key);
      final tampered = EncryptedPayload(
        ciphertext: Uint8List.fromList(payload.ciphertext),
        nonce: payload.nonce,
        mac: Uint8List.fromList(payload.mac),
      );
      tampered.ciphertext[0] ^= 0xFF;

      expect(
        () => service.decryptTextMessage(tampered, key),
        throwsException,
      );
    });

    test('wrong key cannot decrypt the message', () async {
      final payload = await service.encryptTextMessage('nội dung', key);
      final wrongKey = Uint8List.fromList(List<int>.filled(32, 7));

      expect(
        () => service.decryptTextMessage(payload, wrongKey),
        throwsException,
      );
    });
  });

  group('ChatMessage model', () {
    test('isMine is true only for the local sender', () {
      final mine = ChatMessage(
        id: '1',
        senderId: 'me',
        senderName: 'Tôi',
        timestamp: DateTime.now(),
        type: MessageType.text,
      );
      final other = ChatMessage(
        id: '2',
        senderId: 'other',
        senderName: 'Bố',
        timestamp: DateTime.now(),
        type: MessageType.text,
      );
      expect(mine.isMine, isTrue);
      expect(other.isMine, isFalse);
    });

    test('isEncrypted defaults to true', () {
      final msg = ChatMessage(
        id: '1',
        senderId: 'me',
        senderName: 'Tôi',
        timestamp: DateTime.now(),
        type: MessageType.text,
      );
      expect(msg.isEncrypted, isTrue);
    });
  });
}
