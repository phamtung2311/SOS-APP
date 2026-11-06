import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';

void main() {
  group('CryptoService offline security', () {
    test('ECDH key agreement derives the same AES-256 key', () async {
      final service = CryptoService();
      final alice = await service.generateKeyPairX25519();
      final bob = await service.generateKeyPairX25519();

      final aliceShared = await service.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await service.importPublicKey(
          await service.exportPublicKey(bob),
        ),
      );
      final bobShared = await service.deriveSharedKey(
        myKeyPair: bob,
        theirPublicKey: await service.importPublicKey(
          await service.exportPublicKey(alice),
        ),
      );

      final aliceSharedBytes = await aliceShared.extractBytes();
      final bobSharedBytes = await bobShared.extractBytes();

      expect(aliceSharedBytes, equals(bobSharedBytes));
      expect(aliceSharedBytes.length, 32);
    });

    test('round-trip encryption and decryption preserves payload data', () async {
      final service = CryptoService();
      final alice = await service.generateKeyPairX25519();
      final bob = await service.generateKeyPairX25519();

      final keyA = await service.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await service.importPublicKey(
          await service.exportPublicKey(bob),
        ),
      );
      final keyB = await service.deriveSharedKey(
        myKeyPair: bob,
        theirPublicKey: await service.importPublicKey(
          await service.exportPublicKey(alice),
        ),
      );

      final encrypted = await service.encryptLocationPayload(
        lat: 21.0285,
        lng: 105.8542,
        key: keyA,
      );
      final decrypted = await service.decryptLocationPayload(
        encryptedBase64: encrypted,
        key: keyB,
      );

      expect(decrypted['lat'], 21.0285);
      expect(decrypted['lng'], 105.8542);
      expect(decrypted['timestamp'], isA<int>());
    });

    test('tampered payload or wrong key throws an exception', () async {
      final service = CryptoService();
      final alice = await service.generateKeyPairX25519();
      final bob = await service.generateKeyPairX25519();
      final carol = await service.generateKeyPairX25519();

      final sharedKey = await service.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await service.importPublicKey(
          await service.exportPublicKey(bob),
        ),
      );
      final wrongKey = await service.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await service.importPublicKey(
          await service.exportPublicKey(carol),
        ),
      );

      final encrypted = await service.encryptLocationPayload(
        lat: 21.0285,
        lng: 105.8542,
        key: sharedKey,
      );

      final tampered = encrypted.substring(0, encrypted.length - 1) +
          (encrypted.endsWith('A') ? 'B' : 'A');

      expect(
        () => service.decryptLocationPayload(
          encryptedBase64: tampered,
          key: sharedKey,
        ),
        throwsException,
      );

      expect(
        () => service.decryptLocationPayload(
          encryptedBase64: encrypted,
          key: wrongKey,
        ),
        throwsException,
      );
    });

    test('nonce randomness ensures unique ciphertext for each encryption', () async {
      final service = CryptoService();
      final alice = await service.generateKeyPairX25519();
      final bob = await service.generateKeyPairX25519();

      final key = await service.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await service.importPublicKey(
          await service.exportPublicKey(bob),
        ),
      );

      final ciphertexts = <String>[];
      for (var i = 0; i < 100; i++) {
        ciphertexts.add(
          await service.encryptLocationPayload(
            lat: 21.0285,
            lng: 105.8542,
            key: key,
          ),
        );
      }

      expect(ciphertexts.toSet().length, 100);
    });
  });
}
