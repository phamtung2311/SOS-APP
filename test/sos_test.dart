import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/data/models/encrypted_sos_payload.dart';
import 'package:sos_safe_family/data/models/sos_event.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/replay_guard.dart';
import 'package:sos_safe_family/data/services/sos_service.dart';

void main() {
  group('SosEvent model — đóng gói payload', () {
    final DateTime ts = DateTime.fromMillisecondsSinceEpoch(1730000000000);

    SosEvent buildEvent({SosStatus status = SosStatus.active}) => SosEvent(
          sosId: 'sos-abc-123',
          senderName: 'Tùng',
          lat: 21.0285,
          lng: 105.8542,
          isMocked: false,
          batteryLevel: 87,
          timestamp: ts,
          status: status,
        );

    test('toJson chứa đủ 8 trường bắt buộc', () {
      final json = buildEvent().toJson();

      expect(json.keys, containsAll(<String>[
        'sosId',
        'senderName',
        'lat',
        'lng',
        'isMocked',
        'batteryLevel',
        'timestamp',
        'status',
      ]));
      expect(json['sosId'], 'sos-abc-123');
      expect(json['senderName'], 'Tùng');
      expect(json['lat'], 21.0285);
      expect(json['lng'], 105.8542);
      expect(json['isMocked'], isFalse);
      expect(json['batteryLevel'], 87);
      expect(json['timestamp'], 1730000000000);
      expect(json['status'], 'ACTIVE');
    });

    test('status dùng tên wire đúng quy ước', () {
      expect(buildEvent().toJson()['status'], 'ACTIVE');
      expect(buildEvent(status: SosStatus.resolved).toJson()['status'], 'RESOLVED');
      expect(SosStatus.active.wireName, 'ACTIVE');
      expect(SosStatus.resolved.wireName, 'RESOLVED');
    });

    test('toJson / fromJson round-trip giữ nguyên dữ liệu', () {
      final original = buildEvent();
      final restored = SosEvent.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.sosId, original.sosId);
      expect(restored.senderName, original.senderName);
      expect(restored.lat, original.lat);
      expect(restored.lng, original.lng);
      expect(restored.isMocked, original.isMocked);
      expect(restored.batteryLevel, original.batteryLevel);
      expect(restored.timestamp, original.timestamp);
      expect(restored.status, original.status);
    });

    test('fromJson đọc được status lowercase và giá trị lạ', () {
      expect(
        SosEvent.fromJson(const {'status': 'active'}).status,
        SosStatus.active,
      );
      expect(
        SosEvent.fromJson(const {'status': 'RESOLVED'}).status,
        SosStatus.resolved,
      );
      expect(
        SosEvent.fromJson(const {'status': 'WHATEVER'}).status,
        SosStatus.active,
      );
    });

    test('copyWith không đổi các trường không chỉ định', () {
      final original = buildEvent();
      final updated = original.copyWith(batteryLevel: 55);
      expect(updated.batteryLevel, 55);
      expect(updated.sosId, original.sosId);
      expect(updated.lat, original.lat);
    });
  });

  group('Vòng đời trạng thái ACTIVE → RESOLVED', () {
    SosEvent buildEvent() => SosEvent(
          sosId: 'sos-1',
          senderName: 'Tùng',
          lat: 21.0285,
          lng: 105.8542,
          isMocked: false,
          batteryLevel: 87,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1730000000000),
        );

    test('sự kiện mới khởi tạo ở trạng thái ACTIVE', () {
      final event = buildEvent();
      expect(event.status, SosStatus.active);
      expect(event.isActive, isTrue);
      expect(event.isResolved, isFalse);
      expect(event.resolvedAt, isNull);
    });

    test('resolve() chuyển ACTIVE → RESOLVED và ghi thời điểm', () {
      final event = buildEvent();
      final resolved = event.resolve(at: DateTime.fromMillisecondsSinceEpoch(1730000060000));

      expect(resolved.status, SosStatus.resolved);
      expect(resolved.isActive, isFalse);
      expect(resolved.isResolved, isTrue);
      expect(resolved.resolvedAt, isNotNull);
      expect(
        resolved.resolvedAt!.millisecondsSinceEpoch,
        1730000060000,
      );
    });

    test('resolve() không thay đổi bản gốc (immutability)', () {
      final event = buildEvent();
      event.resolve();
      expect(event.status, SosStatus.active);
      expect(event.resolvedAt, isNull);
    });

    test('toJson của sự kiện đã resolve chứa resolvedAt', () {
      final resolved = buildEvent().resolve();
      final json = resolved.toJson();
      expect(json['status'], 'RESOLVED');
      expect(json['resolvedAt'], isA<int>());
    });

    test('fromJson khôi phục được sự kiện đã resolve', () {
      final resolved = buildEvent().resolve(
        at: DateTime.fromMillisecondsSinceEpoch(1730000060000),
      );
      final restored = SosEvent.fromJson(
        jsonDecode(jsonEncode(resolved.toJson())) as Map<String, dynamic>,
      );
      expect(restored.status, SosStatus.resolved);
      expect(restored.resolvedAt!.millisecondsSinceEpoch, 1730000060000);
    });
  });

  group('Mã hóa payload SOS bằng AES-256-GCM', () {
    late CryptoService crypto;
    late SosService sosService;
    late Uint8List key;

    setUp(() async {
      crypto = CryptoService();
      sosService = SosService(cryptoService: crypto);

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

    SosEvent buildEvent() => SosEvent(
          sosId: 'sos-secret-1',
          senderName: 'Tùng',
          lat: 21.0285,
          lng: 105.8542,
          isMocked: false,
          batteryLevel: 87,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1730000000000),
        );

    test('payload mã hóa không chứa toạ độ gốc dạng plaintext', () async {
      final payload = await sosService.encryptEvent(event: buildEvent(), key: key);

      final String blob = '${payload.encryptedEvent}${payload.encryptedLocation}';

      expect(blob.contains('21.0285'), isFalse);
      expect(blob.contains('105.8542'), isFalse);
      expect(blob.contains('sos-secret-1'), isFalse);
      expect(blob.contains('Tùng'), isFalse);

      // Dạng base64 của toạ độ cũng không xuất hiện.
      expect(blob.contains(base64Encode(utf8.encode('21.0285'))), isFalse);
    });

    test('giải mã lại được đúng toạ độ gốc bằng đúng khoá', () async {
      final event = buildEvent();
      final payload = await sosService.encryptEvent(event: event, key: key);

      final decrypted = await crypto.decryptLocationPayload(
        encryptedBase64: payload.encryptedLocation,
        key: SecretKey(key),
      );
      expect(decrypted['lat'], 21.0285);
      expect(decrypted['lng'], 105.8542);
    });

    test('giải mã được toàn bộ sự kiện từ encryptedEvent', () async {
      final event = buildEvent();
      final payload = await sosService.encryptEvent(event: event, key: key);

      // encryptedEvent dùng định dạng vận chuyển: nonce || mac || ciphertext.
      final wire = EncryptedPayload.fromTransportBytes(
        base64Decode(payload.encryptedEvent),
      );
      final decoded =
          jsonDecode(await crypto.decryptTextMessage(wire, key))
              as Map<String, dynamic>;
      expect(decoded['sosId'], 'sos-secret-1');
      expect(decoded['status'], 'ACTIVE');
      expect(decoded['lat'], 21.0285);
      expect(decoded['batteryLevel'], 87);
    });

    test('nonce ngẫu nhiên: hai lần mã hóa cho ciphertext khác nhau', () async {
      final event = buildEvent();
      final first = await sosService.encryptEvent(event: event, key: key);
      final second = await sosService.encryptEvent(event: event, key: key);

      expect(first.encryptedEvent, isNot(second.encryptedEvent));
      expect(first.encryptedLocation, isNot(second.encryptedLocation));
    });

    test('khoá sai không giải mã được payload SOS', () async {
      final payload = await sosService.encryptEvent(event: buildEvent(), key: key);
      final wrongKey = Uint8List.fromList(List<int>.filled(32, 9));

      expect(
        () => crypto.decryptLocationPayload(
          encryptedBase64: payload.encryptedLocation,
          key: SecretKey(wrongKey),
        ),
        throwsException,
      );
    });

    test('payload tampered bị từ chối bởi MAC', () async {
      final payload = await sosService.encryptEvent(event: buildEvent(), key: key);
      final tampered = payload.encryptedLocation.substring(
            0,
            payload.encryptedLocation.length - 1,
          ) +
          (payload.encryptedLocation.endsWith('A') ? 'B' : 'A');

      expect(
        () => crypto.decryptLocationPayload(
          encryptedBase64: tampered,
          key: SecretKey(key),
        ),
        throwsException,
      );
    });

    test('toWireJson không rò rỉ toạ độ gốc', () async {
      final payload = await sosService.encryptEvent(event: buildEvent(), key: key);
      final wire = payload.toWireJson();

      expect(wire['sosId'], 'sos-secret-1');
      expect(wire['encryptedEvent'], isA<String>());
      expect(wire['encryptedLocation'], isA<String>());
      expect(wire.containsKey('lat'), isFalse);
      expect(wire.containsKey('lng'), isFalse);
      expect(jsonEncode(wire).contains('21.0285'), isFalse);
    });
  });

  group('Tích hợp ReplayGuard vào luồng nhận SOS (handleIncomingSos)', () {
    late CryptoService crypto;
    late SosService sosService;
    late Uint8List key;

    setUp(() async {
      crypto = CryptoService();
      sosService = SosService(cryptoService: crypto);

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
          sosId: 'sos-replay-01',
          senderName: 'Mai',
          lat: 21.0285,
          lng: 105.8542,
          isMocked: false,
          batteryLevel: 87,
          timestamp: DateTime.now().subtract(age),
        );

    test('gói SOS hợp lệ được chấp nhận và giải mã đúng toạ độ', () async {
      final payload = await sosService.encryptEvent(
        event: buildEvent(),
        key: key,
      );

      final received = await sosService.handleIncomingSos(
        encryptedPayload: payload,
        sharedKey: SecretKey(key),
      );

      expect(received.sosId, 'sos-replay-01');
      expect(received.senderName, 'Mai');
      expect(received.lat, 21.0285);
      expect(received.lng, 105.8542);
      expect(received.batteryLevel, 87);
      expect(received.isActive, isTrue);
    });

    test('gói SOS gửi lại cùng nonce bị từ chối với duplicateNonce', () async {
      final payload = await sosService.encryptEvent(
        event: buildEvent(),
        key: key,
      );

      // Lần 1: hợp lệ.
      await sosService.handleIncomingSos(
        encryptedPayload: payload,
        sharedKey: SecretKey(key),
      );

      // Lần 2: cùng nonce -> chặn đứng.
      expect(
        () => sosService.handleIncomingSos(
          encryptedPayload: payload,
          sharedKey: SecretKey(key),
        ),
        throwsA(
          isA<ReplayAttackException>().having(
            (ReplayAttackException e) => e.verdict,
            'verdict',
            ReplayVerdict.duplicateNonce,
          ),
        ),
      );
    });

    test('gói SOS cũ hơn AppConstants.sosExpiresAfter bị từ chối với expired',
        () async {
      // Timestamp cũ 50 phút -> vượt ngưỡng 30 phút.
      final payload = await sosService.encryptEvent(
        event: buildEvent(age: const Duration(minutes: 50)),
        key: key,
      );

      expect(
        () => sosService.handleIncomingSos(
          encryptedPayload: payload,
          sharedKey: SecretKey(key),
        ),
        throwsA(
          isA<ReplayAttackException>().having(
            (ReplayAttackException e) => e.verdict,
            'verdict',
            ReplayVerdict.expired,
          ),
        ),
      );
    });

    test('gói SOS bị can thiệp ciphertext bị từ chối bởi MAC', () async {
      final payload = await sosService.encryptEvent(
        event: buildEvent(),
        key: key,
      );

      final tampered = payload.encryptedEvent.replaceRange(
        payload.encryptedEvent.length - 2,
        payload.encryptedEvent.length - 1,
        payload.encryptedEvent.endsWith('A') ? 'B' : 'A',
      );

      expect(
        () => sosService.handleIncomingSos(
          encryptedPayload: EncryptedSosPayload(
            event: payload.event,
            encryptedEvent: tampered,
            encryptedLocation: payload.encryptedLocation,
            sentAt: payload.sentAt,
          ),
          sharedKey: SecretKey(key),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('ReplayGuard từ chối gói tin hợp lệ trước khi tốn công giải mã',
        () async {
      // Guard dùng chung: gói tin đã đi qua 1 lần sẽ bị chặn ở lần 2.
      final guard = ReplayGuard();
      final guarded = SosService(cryptoService: crypto, replayGuard: guard);
      final payload = await guarded.encryptEvent(
        event: buildEvent(),
        key: key,
      );

      await guarded.handleIncomingSos(
        encryptedPayload: payload,
        sharedKey: SecretKey(key),
      );

      expect(guard.trackedNonceCount, 1);
      expect(guard.hasSeen(payload.nonceBase64), isTrue);
      expect(payload.nonceBase64, isNotEmpty);
    });
  });
}
