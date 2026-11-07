import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sos_safe_family/data/models/chat_message.dart';
import 'package:sos_safe_family/data/models/sos_event.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/replay_guard.dart';
import 'package:sos_safe_family/data/services/sos_service.dart';
import 'package:sos_safe_family/data/services/tamper_detector.dart';
import 'package:sos_safe_family/core/app_state.dart';

/// Bộ kiểm thử mô phỏng 4 kịch bản tấn công (Milestone 6).
///
///  1. Nghe lén (Eavesdropping/MITM) — payload & tin chat không rò rỉ plaintext.
///  2. Can thiệp dữ liệu (Tampering/Bit-flipping) — AES-256-GCM từ chối MAC sai.
///  3. Phát lại (Replay) — [ReplayGuard] phát hiện gói tin cũ / nonce trùng.
///  4. Giả mạo vị trí (Mock GPS Spoofing) — [TamperDetector] & [AppState].
void main() {
  // Khởi tạo binding để các lệnh gọi MethodChannel native (kiểm tra root)
  // trả về mặc định an toàn thay vì ném lỗi "Binding has not yet been
  // initialized".
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // Kịch bản 1: Tấn công nghe lén (Eavesdropping / MITM)
  // ------------------------------------------------------------------
  group('ATK-01 Eavesdropping / MITM', () {
    late CryptoService crypto;
    late SosService sosService;
    late Uint8List victimKey;
    late SimpleKeyPair attackerKeyPair;

    setUp(() async {
      crypto = CryptoService();
      sosService = SosService(cryptoService: crypto);

      // Nạn nhân (thiết bị gia đình) đã thỏa thuận khóa ECDH với nhau.
      final alice = await crypto.generateKeyPairX25519();
      final bob = await crypto.generateKeyPairX25519();
      final shared = await crypto.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await crypto.importPublicKey(
          await crypto.exportPublicKey(bob),
        ),
      );
      victimKey = Uint8List.fromList(await shared.extractBytes());

      // Kẻ tấn công nắm khóa của MÌNH (không phải khóa nạn nhân).
      attackerKeyPair = await crypto.generateKeyPairX25519();
    });

    test('gói tin SOS bị bắt không chứa tọa độ dạng rõ', () async {
      final event = SosEvent(
        sosId: 'sos-m6-01',
        senderName: 'Mai',
        lat: 21.0285,
        lng: 105.8542,
        isMocked: false,
        batteryLevel: 87,
        timestamp: DateTime.now(),
      );

      final wire = await sosService.encryptEvent(event: event, key: victimKey);

      // Dữ liệu đi trên mạng: encryptedEvent + encryptedLocation (base64).
      // Toạ độ gốc KHÔNG được xuất hiện ở dạng số hay JSON plaintext.
      expect(wire.encryptedEvent, isNot(contains('21.0285')));
      expect(wire.encryptedEvent, isNot(contains('105.8542')));
      expect(wire.encryptedEvent, isNot(contains('"lat"')));
      expect(wire.encryptedEvent, isNot(contains(event.sosId)));
      expect(wire.encryptedLocation, isNot(contains('21.0285')));
      expect(wire.encryptedLocation, isNot(contains('105.8542')));

      // Bên không nắm private key của nạn nhân KHÔNG giải được:
      // dùng khóa ECDH của chính kẻ tấn công để thử — phải ném exception.
      final attackerKey = await crypto.deriveSharedKey(
        myKeyPair: attackerKeyPair,
        theirPublicKey: await crypto.importPublicKey(
          await crypto.exportPublicKey(attackerKeyPair),
        ),
      );
      expect(
        () => crypto.decryptLocationPayload(
          encryptedBase64: wire.encryptedLocation,
          key: attackerKey,
        ),
        throwsException,
      );
    });

    test('tin nhắn chat bị nghe lén: ciphertext & MAC không rò plaintext',
        () async {
      const secret = 'Mật khẩu ví là 951122, tổng tài sản 500 triệu';
      final payload = await crypto.encryptTextMessage(secret, victimKey);

      // Ciphertext, nonce và MAC (3 thứ duy nhất đi trên mạng) không được
      // chứa plaintext hay bất kỳ đoạn nào của nội dung gốc.
      for (final String field in [
        payload.ciphertextBase64,
        payload.nonceBase64,
        payload.macBase64,
      ]) {
        expect(field, isNot(contains('951122')),
            reason: 'rò plaintext qua field: $field');
        expect(field, isNot(contains(secret)),
            reason: 'rò plaintext qua field: $field');
      }

      // Gói tin E2EE của khung chat (dạng lưu ở ChatMessage) cũng vậy.
      final wireMessage = ChatMessage(
        id: 'm6-msg',
        senderId: 'me',
        senderName: 'Mai',
        timestamp: DateTime.now(),
        type: MessageType.text,
        ciphertextBase64: payload.ciphertextBase64,
        nonceBase64: payload.nonceBase64,
        macBase64: payload.macBase64,
      );
      expect(wireMessage.ciphertextBase64, isNot(contains('951122')));
    });
  });

  // ------------------------------------------------------------------
  // Kịch bản 2: Tấn công sửa đổi dữ liệu (Tampering / Bit-flipping)
  // ------------------------------------------------------------------
  group('ATK-02 Tampering (bit-flipping)', () {
    late CryptoService crypto;
    late Uint8List key;

    setUp(() async {
      crypto = CryptoService();
      final alice = await crypto.generateKeyPairX25519();
      final bob = await crypto.generateKeyPairX25519();
      final shared = await crypto.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await crypto.importPublicKey(
          await crypto.exportPublicKey(bob),
        ),
      );
      key = Uint8List.fromList(await shared.extractBytes());
    });

    test('đảo 1 bit trong ciphertext -> GCM từ chối (MAC mismatch)',
        () async {
      final payload = await crypto.encryptTextMessage('SOS tại ngã ba', key);

      final flipped = Uint8List.fromList(payload.ciphertext);
      flipped[0] = flipped[0] ^ 0x01; // bit-flip tại byte đầu.
      final tampered = EncryptedPayload(
        ciphertext: flipped,
        nonce: payload.nonce,
        mac: payload.mac,
      );

      expect(
        () => crypto.decryptTextMessage(tampered, key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('đảo 1 bit trong MAC -> GCM từ chối', () async {
      final payload = await crypto.encryptTextMessage('SOS tại ngã ba', key);

      final flippedMac = Uint8List.fromList(payload.mac);
      flippedMac[5] = flippedMac[5] ^ 0x40;
      final tampered = EncryptedPayload(
        ciphertext: payload.ciphertext,
        nonce: payload.nonce,
        mac: flippedMac,
      );

      expect(
        () => crypto.decryptTextMessage(tampered, key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('đổi nonce (re-encryption bằng nonce khác) -> GCM từ chối',
        () async {
      final payload = await crypto.encryptTextMessage('SOS tại ngã ba', key);

      // Kẻ tấn công thử thay nonce bằng nonce ngẫu nhiên của lần mã hóa khác
      // để "nhận trót" gói tin cho mã của mình — MAC phải vẫn không khớp.
      final otherNonce = (await crypto.encryptTextMessage('x', key)).nonce;
      final tampered = EncryptedPayload(
        ciphertext: payload.ciphertext,
        nonce: otherNonce,
        mac: payload.mac,
      );

      expect(
        () => crypto.decryptTextMessage(tampered, key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  // ------------------------------------------------------------------
  // Kịch bản 3: Tấn công phát lại (Replay Attack)
  // ------------------------------------------------------------------
  group('ATK-03 Replay attack', () {
    test('nonce đã ghi nhận: phát lại cùng gói tin -> bị từ chối', () {
      final guard = ReplayGuard();
      const nonce = 'bW9jaw==';
      final sentAt = DateTime(2026, 11, 7, 8, 0);
      final now = sentAt.add(const Duration(minutes: 1));

      expect(
          guard.check(nonceBase64: nonce, timestamp: sentAt, now: now),
          ReplayVerdict.accepted);

      // Kẻ tấn công phát lại chính xác gói tin cũ (vẫn trong hạn tuổi).
      expect(
          guard.check(nonceBase64: nonce, timestamp: sentAt, now: now),
          ReplayVerdict.duplicateNonce);
      expect(guard.hasSeen(nonce), isTrue);
    });

    test('gói tin cũ hơn thời hạn (> maxAge) -> hết hạn, không chấp nhận', () {
      // Default: tuổi tối đa = AppConstants.sosExpiresAfter (30 phút).
      final guard = ReplayGuard();
      final now = DateTime(2026, 11, 7, 9, 0);
      final staleTimestamp = now.subtract(const Duration(minutes: 31));

      expect(guard.check(nonceBase64: 'n1', timestamp: staleTimestamp, now: now),
          ReplayVerdict.expired);
      expect(guard.hasSeen('n1'), isFalse,
          reason: 'gói tin hết hạn không được ghi nhận nonce');
    });

    test('tự cấu hình ngưỡng 15 phút: gói tin 16 phút bị từ chối', () {
      final guard = ReplayGuard(maxAge: const Duration(minutes: 15));
      final now = DateTime(2026, 11, 7, 9, 0);

      expect(guard.check(nonceBase64: 'a', timestamp: now, now: now),
          ReplayVerdict.accepted);
      expect(
          guard.check(
            nonceBase64: 'b',
            timestamp: now.subtract(const Duration(minutes: 16)),
            now: now,
          ),
          ReplayVerdict.expired);
    });

    test('nonce cũ bị quên sau maxAge -> không giữ bộ nhớ vô hạn', () {
      final guard = ReplayGuard(maxAge: const Duration(minutes: 15));
      final t0 = DateTime(2026, 11, 7, 8, 0);
      final t1 = t0.add(const Duration(minutes: 30));

      expect(guard.check(nonceBase64: 'old', timestamp: t0, now: t0),
          ReplayVerdict.accepted);

      // 30 phút sau, một gói tin hợp lệ khác được xử lý -> nonce cũ bị xóa.
      expect(guard.check(nonceBase64: 'new', timestamp: t1, now: t1),
          ReplayVerdict.accepted);
      expect(guard.hasSeen('old'), isFalse);
    });

    test('gói tin SOS bị replay ném ReplayAttackException (luồng nhận tin)',
        () {
      // Mô phỏng máy chủ nhận: mọi gói tin SOS đều qua ReplayGuard.
      final guard = ReplayGuard();
      final receivedAt = DateTime(2026, 11, 7, 10, 30);
      const capturedNonce = 'Q0FQX05PTkNFXw==';

      guard.check(
        nonceBase64: capturedNonce,
        timestamp: receivedAt,
        now: receivedAt,
      );

      // Kẻ tấn công phát lại gói tin đã bắt được 20 phút trước:
      expect(
        () {
          final verdict = guard.check(
            nonceBase64: capturedNonce,
            timestamp: receivedAt,
            now: receivedAt,
          );
          if (verdict != ReplayVerdict.accepted) {
            throw ReplayAttackException(verdict);
          }
        },
        throwsA(isA<ReplayAttackException>()),
      );
    });
  });

  // ------------------------------------------------------------------
  // Kịch bản 3b: Tích hợp ReplayGuard vào luồng nhận SOS (Milestone 7)
  // ------------------------------------------------------------------
  group('ATK-03b ReplayGuard tích hợp vào SosService & AppState', () {
    late CryptoService crypto;
    late Uint8List key;

    setUp(() async {
      crypto = CryptoService();
      final alice = await crypto.generateKeyPairX25519();
      final bob = await crypto.generateKeyPairX25519();
      final shared = await crypto.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await crypto.importPublicKey(
          await crypto.exportPublicKey(bob),
        ),
      );
      key = Uint8List.fromList(await shared.extractBytes());
    });

    SosEvent buildEvent({Duration age = Duration.zero}) => SosEvent(
          sosId: 'sos-replay-int',
          senderName: 'Mai',
          lat: 21.0285,
          lng: 105.8542,
          isMocked: false,
          batteryLevel: 87,
          timestamp: DateTime.now().subtract(age),
        );

    test('SosService.receiveSos: gói tin hợp lệ -> giải mã & kích hoạt',
        () async {
      final sosService = SosService(cryptoService: crypto);
      final wire =
          await sosService.encryptEvent(event: buildEvent(), key: key);

      final received = await sosService.receiveSos(
        encryptedEventBase64: wire.encryptedEvent,
        encryptedLocationBase64: wire.encryptedLocation,
        key: key,
      );

      expect(received.sosId, 'sos-replay-int');
      expect(received.lat, 21.0285);
      expect(received.lng, 105.8542);
      expect(received.isActive, isTrue);
    });

    test('SosService.receiveSos: phát lại cùng gói tin -> ném '
        'ReplayAttackException (duplicateNonce)', () async {
      final sosService = SosService(cryptoService: crypto);
      final wire =
          await sosService.encryptEvent(event: buildEvent(), key: key);

      // Lần 1: hợp lệ.
      await sosService.receiveSos(
        encryptedEventBase64: wire.encryptedEvent,
        encryptedLocationBase64: wire.encryptedLocation,
        key: key,
      );

      // Lần 2: cùng nonce -> từ chối (replay).
      expect(
        () => sosService.receiveSos(
          encryptedEventBase64: wire.encryptedEvent,
          encryptedLocationBase64: wire.encryptedLocation,
          key: key,
        ),
        throwsA(isA<ReplayAttackException>()),
      );
    });

    test('SosService.receiveSos: gói tin quá hạn tuổi -> ném '
        'ReplayAttackException (expired)', () async {
      final sosService = SosService(cryptoService: crypto);
      // Timestamp cũ 50 phút -> vượt ngưỡng AppConstants.sosExpiresAfter (30').
      final wire = await sosService.encryptEvent(
        event: buildEvent(age: const Duration(minutes: 50)),
        key: key,
      );

      expect(
        () => sosService.receiveSos(
          encryptedEventBase64: wire.encryptedEvent,
          encryptedLocationBase64: wire.encryptedLocation,
          key: key,
        ),
        throwsA(isA<ReplayAttackException>()),
      );
    });

    test('AppState.receiveIncomingSos: gói tin hợp lệ kích hoạt cảnh báo '
        'và ghi audit log', () async {
      final sender = SosService(cryptoService: crypto);
      final wire =
          await sender.encryptEvent(event: buildEvent(), key: key);

      final state = AppState(cryptoService: crypto);
      final received = await state.receiveIncomingSos(
        encryptedEventBase64: wire.encryptedEvent,
        encryptedLocationBase64: wire.encryptedLocation,
        key: key,
      );

      expect(received, isNotNull);
      expect(received!.sosId, 'sos-replay-int');
      expect(state.isSosActive, isTrue);
      expect(
          state.auditLogs.any((String l) => l.contains('Nhận cảnh báo SOS')),
          isTrue);
    });

    test('AppState.receiveIncomingSos: replay bị từ chối, không kích hoạt, '
        'ghi cảnh báo tấn công vào audit log', () async {
      final sender = SosService(cryptoService: crypto);
      final wire =
          await sender.encryptEvent(event: buildEvent(), key: key);

      final state = AppState(cryptoService: crypto);

      // Gói tin đầu: hợp lệ.
      final first = await state.receiveIncomingSos(
        encryptedEventBase64: wire.encryptedEvent,
        encryptedLocationBase64: wire.encryptedLocation,
        key: key,
      );
      expect(first, isNotNull);
      expect(state.isSosActive, isTrue);

      // Kẻ tấn công phát lại đúng gói tin cũ.
      final replay = await state.receiveIncomingSos(
        encryptedEventBase64: wire.encryptedEvent,
        encryptedLocationBase64: wire.encryptedLocation,
        key: key,
      );

      expect(replay, isNull, reason: 'gói tin phát lại phải bị từ chối');
      expect(
          state.auditLogs.any((String l) => l.contains('TẤN CÔNG')), isTrue,
          reason: 'phải ghi cảnh báo tấn công vào nhật ký kiểm toán');
    });
  });

  // ------------------------------------------------------------------
  // Kịch bản 4: Tấn công giả mạo vị trí (Mock GPS Spoofing)
  // ------------------------------------------------------------------
  group('ATK-04 Mock GPS spoofing', () {
    Position fakePosition({required bool isMocked}) {
      return Position(
        latitude: 21.0285,
        longitude: 105.8542,
        timestamp: DateTime(2026, 11, 7),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: isMocked,
      );
    }

    test('TamperDetector nhận ra Position(isMocked: true)', () {
      final detector = TamperDetector();
      expect(detector.isMockLocation(fakePosition(isMocked: true)), isTrue);
      expect(detector.isMockLocation(fakePosition(isMocked: false)), isFalse);
    });

    test('TamperReport.isTrusted = false khi GPS giả lập, nhãn cảnh báo đúng',
        () async {
      final detector = TamperDetector();

      final bad = await detector.inspect(
        position: fakePosition(isMocked: true),
        screenCaptureProtected: true,
      );
      expect(bad.isMockLocation, isTrue);
      expect(bad.isTrusted, isFalse);
      expect(bad.gpsLabel, startsWith('Phát hiện GPS giả lập'));

      final good = await detector.inspect(
        position: fakePosition(isMocked: false),
        screenCaptureProtected: true,
      );
      expect(good.isMockLocation, isFalse);
      expect(good.isTrusted, isTrue);
      expect(good.gpsLabel, startsWith('GPS thực tế'));
    });

    test('AppState: nhận Position mock -> isMockGps & cảnh báo toàn vẹn',
        () async {
      final state = AppState();
      state.updatePosition(fakePosition(isMocked: true));

      expect(state.isMockGps, isTrue);

      final report = await state.refreshTamperReport();
      expect(report.isTrusted, isFalse,
          reason: 'phải cảnh báo gian lận tọa độ');
      expect(report.gpsLabel, startsWith('Phát hiện GPS giả lập'));

      // Vị trí thật quay về -> thiết bị đáng tin trở lại.
      state.updatePosition(fakePosition(isMocked: false));
      expect(state.isMockGps, isFalse);
      final recovered = await state.refreshTamperReport();
      expect(recovered.isTrusted, isTrue);
    });
  });
}
