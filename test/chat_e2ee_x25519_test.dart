import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/data/models/chat_message.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';

void main() {
  group('Chat E2EE X25519 & Firestore Payload Verification', () {
    late CryptoService crypto;

    setUp(() {
      crypto = CryptoService();
    });

    // (i) 2 bên có public key khác nhau → cùng 1 shared key
    test('(i) 2 bên có public key khác nhau sinh ra cùng 1 shared key qua ECDH X25519', () async {
      // 1. Sinh cặp khóa độc lập cho Alice và Bob
      final aliceKeyPair = await crypto.generateKeyPairX25519();
      final bobKeyPair = await crypto.generateKeyPairX25519();

      final alicePubB64 = await crypto.exportPublicKey(aliceKeyPair);
      final bobPubB64 = await crypto.exportPublicKey(bobKeyPair);

      // Khẳng định 2 public key hoàn toàn khác biệt
      expect(alicePubB64, isNot(equals(bobPubB64)));

      // 2. Thỏa thuận khóa Diffie-Hellman (ECDH)
      // Phía Alice dùng private key của mình + public key của Bob
      final aliceSharedKey = await crypto.deriveChatKeyForPeer(
        myKeyPair: aliceKeyPair,
        theirPublicKeyB64: bobPubB64,
      );

      // Phía Bob dùng private key của mình + public key của Alice
      final bobSharedKey = await crypto.deriveChatKeyForPeer(
        myKeyPair: bobKeyPair,
        theirPublicKeyB64: alicePubB64,
      );

      // 3. Khẳng định: Cả hai phía tính ra cùng 1 khóa bí mật AES-256 (32 byte)
      expect(aliceSharedKey, equals(bobSharedKey));
      expect(aliceSharedKey.length, 32);

      // 4. Kiểm tra mã hóa và giải mã thông suốt 2 chiều bằng khóa này
      const originalMessage = 'Chào Bob, đây là tin nhắn bí mật đầu cuối!';
      final payload = await crypto.encryptTextMessage(originalMessage, aliceSharedKey);
      final decryptedByBob = await crypto.decryptTextMessage(payload, bobSharedKey);
      expect(decryptedByBob, equals(originalMessage));
    });

    // (ii) key E2EE ≠ key fallback
    test('(ii) Khóa E2EE thực sự khác biệt với khóa fallback tĩnh deriveRoomKey', () async {
      final aliceKeyPair = await crypto.generateKeyPairX25519();
      final bobKeyPair = await crypto.generateKeyPairX25519();
      final bobPubB64 = await crypto.exportPublicKey(bobKeyPair);

      // Khóa E2EE thật thỏa thuận qua ECDH X25519
      final e2eeKey = await crypto.deriveChatKeyForPeer(
        myKeyPair: aliceKeyPair,
        theirPublicKeyB64: bobPubB64,
      );

      // Khóa fallback tĩnh theo roomId (chỉ SHA-256 của chuỗi tĩnh)
      const roomId = 'chat_alice_gmail_com___bob_gmail_com';
      final fallbackKey = await crypto.deriveRoomKey(roomId);

      // Khẳng định khóa E2EE tuyệt đối không trùng với khóa fallback
      expect(e2eeKey, isNot(equals(fallbackKey)));
      expect(e2eeKey.length, 32);
      expect(fallbackKey.length, 32);

      // Tin nhắn mã hóa bằng E2EE key sẽ KHÔNG THỂ giải mã được bằng fallbackKey
      final payload = await crypto.encryptTextMessage('Bảo mật tuyệt đối', e2eeKey);
      expect(
        () => crypto.decryptTextMessage(payload, fallbackKey),
        throwsException,
      );
    });

    // (iii) document Firestore KHÔNG còn field plaintext (test trên map trả về từ hàm serialize)
    test('(iii) Document Firestore serialize KHÔNG còn field plaintext cho cả text và media', () async {
      final aliceKeyPair = await crypto.generateKeyPairX25519();
      final bobKeyPair = await crypto.generateKeyPairX25519();
      final sharedKey = await crypto.deriveChatKeyForPeer(
        myKeyPair: aliceKeyPair,
        theirPublicKeyB64: await crypto.exportPublicKey(bobKeyPair),
      );

      // --- Trường hợp 1: Tin nhắn văn bản (Text message) ---
      const secretText = 'Mã OTP bí mật: 987654';
      final textPayload = await crypto.encryptTextMessage(secretText, sharedKey);
      final textMessage = ChatMessage(
        id: 'msg-text-001',
        senderId: 'user_alice_uid',
        senderName: 'Alice',
        timestamp: DateTime.now(),
        type: MessageType.text,
        plaintext: secretText, // Lưu trong RAM
        ciphertextBase64: textPayload.ciphertextBase64,
        nonceBase64: textPayload.nonceBase64,
        macBase64: textPayload.macBase64,
        status: MessageStatus.sent,
      );

      final textDocMap = textMessage.serializeForFirestore(
        senderEmail: 'alice@family.vn',
        createdAt: '2026-11-08T12:00:00Z',
      );

      // Chứng minh KHÔNG có trường 'plaintext'
      expect(textDocMap.containsKey('plaintext'), isFalse,
          reason: 'Document Firestore tuyệt đối không được chứa trường plaintext');
      // Chứng minh có đầy đủ trường bản mã và siêu dữ liệu cần thiết
      expect(textDocMap['ciphertextBase64'], equals(textPayload.ciphertextBase64));
      expect(textDocMap['nonceBase64'], equals(textPayload.nonceBase64));
      expect(textDocMap['macBase64'], equals(textPayload.macBase64));
      expect(textDocMap['type'], equals('text'));
      expect(textDocMap['senderId'], equals('user_alice_uid'));
      expect(textDocMap['senderName'], equals('Alice'));
      expect(textDocMap['senderEmail'], equals('alice@family.vn'));
      expect(textDocMap['createdAt'], equals('2026-11-08T12:00:00Z'));

      // Bản mã Base64 không chứa chuỗi văn bản gốc
      final rawCipherBytes = base64Decode(textDocMap['ciphertextBase64'] as String);
      final rawCipherStr = String.fromCharCodes(rawCipherBytes);
      expect(rawCipherStr.contains(secretText), isFalse);

      // --- Trường hợp 2: Tin nhắn hình ảnh (Media message) ---
      final rawImageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4]);
      final mediaPayload = await crypto.encryptMediaBytes(rawImageBytes, sharedKey);
      final mediaMessage = ChatMessage(
        id: 'msg-media-002',
        senderId: 'user_alice_uid',
        senderName: 'Alice',
        timestamp: DateTime.now(),
        type: MessageType.image,
        plaintext: '[Hình ảnh]', // Text mô tả chỉ ở RAM
        ciphertextBase64: mediaPayload.ciphertextBase64,
        nonceBase64: mediaPayload.nonceBase64,
        macBase64: mediaPayload.macBase64,
        decryptedImageBytes: rawImageBytes, // Dữ liệu ảnh giải mã chỉ ở RAM
        status: MessageStatus.sent,
      );

      final mediaDocMap = mediaMessage.toFirestoreMap(
        senderEmail: 'alice@family.vn',
        createdAt: '2026-11-08T12:05:00Z',
      );

      // Chứng minh KHÔNG có trường 'plaintext' và KHÔNG có dữ liệu ảnh thô
      expect(mediaDocMap.containsKey('plaintext'), isFalse,
          reason: 'Tin nhắn ảnh trên Firestore tuyệt đối không được có plaintext');
      expect(mediaDocMap.containsKey('decryptedImageBytes'), isFalse);
      expect(mediaDocMap['type'], equals('image'));
      expect(mediaDocMap['ciphertextBase64'], equals(mediaPayload.ciphertextBase64));
      expect(mediaDocMap['nonceBase64'], equals(mediaPayload.nonceBase64));
      expect(mediaDocMap['macBase64'], equals(mediaPayload.macBase64));
    });

    test('Trạng thái gửi MessageStatus (sending, sent, failed) và copyWith hoạt động chuẩn xác', () {
      final msg = ChatMessage(
        id: 'msg-status-test',
        senderId: 'me',
        senderName: 'Tôi',
        timestamp: DateTime.now(),
        type: MessageType.text,
        plaintext: 'Test status',
        status: MessageStatus.sending,
      );

      expect(msg.status, equals(MessageStatus.sending));

      // Chuyển sang failed khi ghi Firestore lỗi
      final failedMsg = msg.copyWith(status: MessageStatus.failed);
      expect(failedMsg.status, equals(MessageStatus.failed));
      expect(failedMsg.plaintext, equals('Test status'));

      // Chuyển sang sent khi ghi Firestore thành công
      final sentMsg = failedMsg.copyWith(status: MessageStatus.sent);
      expect(sentMsg.status, equals(MessageStatus.sent));
    });
  });
}
