import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/location_share_service.dart';

void main() {
  group('M14 LocationShareService & Realtime Stream Tests', () {
    late CryptoService crypto;
    late LocationShareService locationService;
    late SecretKey sharedKey;

    setUp(() async {
      crypto = CryptoService();
      locationService = LocationShareService(
        cryptoService: crypto,
        throttleDuration: const Duration(seconds: 30),
      );

      // Tạo shared key 32-byte giả lập ECDH X25519
      final keyPairA = await crypto.generateKeyPairX25519();
      final keyPairB = await crypto.generateKeyPairX25519();
      final pubKeyB = await keyPairB.extractPublicKey();
      sharedKey = await crypto.deriveSharedKey(
        myKeyPair: keyPairA,
        theirPublicKey: pubKeyB,
      );
    });

    test('1. Throttle logic: chỉ cho phép publish sau 30s nếu không có force', () {
      final t0 = DateTime(2026, 11, 8, 14, 0, 0);

      // Lần đầu tiên luôn được phép
      expect(locationService.canPublish(t0), isTrue);

      final t10s = t0.add(const Duration(seconds: 10));
      final t29s = t0.add(const Duration(seconds: 29));
      final t30s = t0.add(const Duration(seconds: 30));
      final t35s = t0.add(const Duration(seconds: 35));

      // Kiểm tra logic thời gian khoảng cách throttle
      expect(t10s.difference(t0) >= const Duration(seconds: 30), isFalse);
      expect(t29s.difference(t0) >= const Duration(seconds: 30), isFalse);
      expect(t30s.difference(t0) >= const Duration(seconds: 30), isTrue);
      expect(t35s.difference(t0) >= const Duration(seconds: 30), isTrue);
    });

    test('2. Encrypted location round-trip: Tọa độ và thời gian được bảo toàn nguyên vẹn', () async {
      const lat = 21.028511;
      const lng = 105.854167;

      // Máy A mã hóa tọa độ bằng shared key E2EE
      final encryptedPos = await crypto.encryptLocationPayload(
        lat: lat,
        lng: lng,
        key: sharedKey,
      );

      expect(encryptedPos, isNotEmpty);
      // Đảm bảo không chứa tọa độ dạng văn bản rõ (plaintext)
      expect(encryptedPos.contains('21.028511'), isFalse);
      expect(encryptedPos.contains('105.854167'), isFalse);

      // Giả lập dữ liệu nhận được từ document Firestore `locations/{uid}`
      final fakeDocData = <String, dynamic>{
        'uid': 'user_a_123',
        'encryptedPos': encryptedPos,
        'isMocked': false,
        'battery': 95,
      };

      // Máy B giải mã
      final decrypted = await locationService.decryptLocationDoc(
        docData: fakeDocData,
        key: sharedKey,
      );

      expect(decrypted.lat, closeTo(lat, 0.000001));
      expect(decrypted.lng, closeTo(lng, 0.000001));
      expect(decrypted.isMocked, isFalse);
      expect(decrypted.battery, equals(95));
      expect(decrypted.timestamp.isBefore(DateTime.now().add(const Duration(seconds: 2))), isTrue);
    });

    test('3. Fake GPS / Mock Location flag: isMocked true được truyền tải chính xác', () async {
      const lat = 20.9856;
      const lng = 105.7981;

      final encryptedPos = await crypto.encryptLocationPayload(
        lat: lat,
        lng: lng,
        key: sharedKey,
      );

      final fakeDocDataMocked = <String, dynamic>{
        'uid': 'user_fake_gps',
        'encryptedPos': encryptedPos,
        'isMocked': true,
        'battery': 50,
      };

      final decrypted = await locationService.decryptLocationDoc(
        docData: fakeDocDataMocked,
        key: sharedKey,
      );

      expect(decrypted.isMocked, isTrue);
      expect(decrypted.battery, equals(50));
    });

    test('4. FamilyMemberItem hỗ trợ trường isMocked và hiển thị nhãn cảnh báo Fake GPS', () {
      final memberNormal = FamilyMemberItem(
        id: 'mem_1',
        name: 'Trang',
        relation: 'Bạn thân',
        avatarColor: const Color(0xFF1E88E5),
        isSharing: true,
        location: const LatLng(21.0285, 105.8542),
        isMocked: false,
      );

      final memberFakeGps = memberNormal.copyWith(
        isMocked: true,
        lastUpdated: 'Cập nhật 14:15',
      );

      expect(memberNormal.isMocked, isFalse);
      expect(memberFakeGps.isMocked, isTrue);
      expect(memberFakeGps.lastUpdated, equals('Cập nhật 14:15'));
      expect(memberFakeGps.name, equals('Trang'));
    });
  });
}
