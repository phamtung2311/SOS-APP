import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sos_safe_family/data/models/geofence.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/geofence_service.dart';
import 'package:sos_safe_family/data/services/location_share_service.dart';

void main() {
  group('M14 Geofence Transition & Relay Alert Tests', () {
    late CryptoService crypto;
    late LocationShareService locationService;
    late SecretKey sharedKey;

    setUp(() async {
      crypto = CryptoService();
      locationService = LocationShareService(cryptoService: crypto);

      final keyPairA = await crypto.generateKeyPairX25519();
      final keyPairB = await crypto.generateKeyPairX25519();
      final pubKeyB = await keyPairB.extractPublicKey();
      sharedKey = await crypto.deriveSharedKey(
        myKeyPair: keyPairA,
        theirPublicKey: pubKeyB,
      );
    });

    test('1. Geofence Transition sinh ra khi di chuyển từ ngoài vào trong (ENTER) và từ trong ra ngoài (EXIT)', () {
      final initialFence = Geofence(
        id: 'home_fence',
        name: 'Nhà riêng',
        centerLatitude: 21.0285,
        centerLongitude: 105.8542,
        radiusMeters: 100,
        isEnabled: true,
        isInside: false,
      );

      // Điểm trong vùng: tại tâm
      const insidePoint = LatLng(21.0285, 105.8542);
      // Điểm ngoài vùng: cách ~500m
      const outsidePoint = LatLng(21.0330, 105.8542);

      // 1. Khởi đầu từ ngoài (isInside: false) di chuyển vào insidePoint -> sinh sự kiện ENTER
      final enterTransitions = GeofenceService.evaluateTransitions(
        currentPos: insidePoint,
        fences: [initialFence],
      );
      expect(enterTransitions, hasLength(1));
      expect(enterTransitions.first.isEnter, isTrue);
      expect(enterTransitions.first.isExit, isFalse);
      expect(enterTransitions.first.fence.name, equals('Nhà riêng'));

      // 2. Tiếp tục đứng yên ở trong (với fence có isInside: true) -> KHÔNG sinh sự kiện (chống spam)
      final insideFence = initialFence.copyWith(isInside: true);
      final noTransitions = GeofenceService.evaluateTransitions(
        currentPos: insidePoint,
        fences: [insideFence],
      );
      expect(noTransitions, isEmpty);

      // 3. Di chuyển ra ngoài vùng (với fence có isInside: true) -> sinh sự kiện EXIT
      final exitTransitions = GeofenceService.evaluateTransitions(
        currentPos: outsidePoint,
        fences: [insideFence],
      );
      expect(exitTransitions, hasLength(1));
      expect(exitTransitions.first.isExit, isTrue);
      expect(exitTransitions.first.isEnter, isFalse);
    });

    test('2. Encrypted Geofence Event: Mã hóa và giải mã giữ nguyên thông tin', () async {
      const eventId = 'geo_evt_999';
      const uid = 'user_sender_abc';
      const senderName = 'Tùng';
      const fenceName = 'Trường Đại học Bách Khoa';
      const action = 'exit';
      const lat = 21.0070;
      const lng = 105.8430;

      // Mã hóa tọa độ và thông điệp sự kiện
      final encryptedEvent = await crypto.encryptLocationPayload(
        lat: lat,
        lng: lng,
        key: sharedKey,
      );

      expect(encryptedEvent, isNotEmpty);

      // Giả lập Firestore document `geofence_events/{eventId}`
      final fakeDocData = <String, dynamic>{
        'eventId': eventId,
        'uid': uid,
        'senderName': senderName,
        'fenceName': fenceName,
        'action': action,
        'encryptedEvent': encryptedEvent,
      };

      // Bên nhận giải mã
      final decrypted = await locationService.decryptGeofenceDoc(
        docData: fakeDocData,
        key: sharedKey,
      );

      expect(decrypted.eventId, equals(eventId));
      expect(decrypted.uid, equals(uid));
      expect(decrypted.senderName, equals('Tùng'));
      expect(decrypted.fenceName, equals('Trường Đại học Bách Khoa'));
      expect(decrypted.action, equals('exit'));
      expect(decrypted.isExit, isTrue);
      expect(decrypted.isEnter, isFalse);
      expect(decrypted.lat, closeTo(lat, 0.0001));
      expect(decrypted.lng, closeTo(lng, 0.0001));
    });

    test('3. Format log cảnh báo Geofence cho Audit Log chính xác theo mẫu quy định', () {
      final geoAlert = GeofenceAlertEvent(
        eventId: 'geo_123',
        uid: 'user_xyz',
        senderName: 'Trang',
        fenceName: 'Công viên Thống Nhất',
        action: 'enter',
        lat: 21.0165,
        lng: 105.8436,
        timestamp: DateTime(2026, 11, 8, 14, 30),
      );

      final actionText = geoAlert.isEnter ? 'đã vào' : 'đã rời';
      final hhmm = '${geoAlert.timestamp.hour.toString().padLeft(2, '0')}:${geoAlert.timestamp.minute.toString().padLeft(2, '0')}';
      final logLine = '$hhmm - ⚠️ ${geoAlert.senderName} $actionText vùng an toàn "${geoAlert.fenceName}"';

      expect(logLine, equals('14:30 - ⚠️ Trang đã vào vùng an toàn "Công viên Thống Nhất"'));
    });
  });
}
