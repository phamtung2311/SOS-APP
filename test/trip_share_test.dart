import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/trip_share_service.dart';

void main() {
  group('TripShareService — Sprint 5A chia sẻ hành trình', () {
    late TripShareService service;

    setUp(() {
      service = TripShareService(cryptoService: CryptoService());
    });

    test('generateCode() sinh chuỗi 6 chữ số ngẫu nhiên', () {
      final String code = service.generateCode();
      expect(code.length, 6);
      expect(RegExp(r'^\d{6}$').hasMatch(code), isTrue);

      final Set<String> codes = <String>{};
      for (int i = 0; i < 20; i++) {
        codes.add(service.generateCode());
      }
      // CSPRNG Random.secure() phải sinh các mã phân tán
      expect(codes.length, greaterThan(15));
    });

    test('hashTripCode() băm SHA-256 thành chuỗi hex 64 ký tự', () async {
      const String code = '123456';
      final String hash1 = await service.hashTripCode(code);
      final String hash2 = await service.hashTripCode(code);

      expect(hash1.length, 64);
      expect(hash1, equals(hash2));
      // Băm SHA-256 chuẩn của '123456'
      expect(
        hash1,
        '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
      );
    });

    test('createTripShare() tạo phiên với TTL 60 phút và băm SHA-256 tương ứng',
        () async {
      final DateTime now = DateTime(2026, 11, 6, 20, 0, 0);
      final (code, share) = await service.createTripShare(
        now: now,
        tripId: 'trip-hanoi-01',
      );

      expect(code.length, 6);
      expect(share.tripId, 'trip-hanoi-01');
      expect(share.createdAt, now);
      expect(share.expiresAt, now.add(const Duration(minutes: 60)));

      // Hash trong share phải khớp với băm của mã gốc
      final String expectedHash = await service.hashTripCode(code);
      expect(share.codeHash, equals(expectedHash));
    });

    test('verifyCode() xác thực thành công mã đúng và từ chối mã sai',
        () async {
      final DateTime now = DateTime(2026, 11, 6, 20, 0, 0);
      final (code, share) = await service.createTripShare(now: now);

      final bool ok = await service.verifyCode(
        code: code,
        share: share,
        now: now.add(const Duration(minutes: 10)),
      );
      expect(ok, isTrue);

      final bool wrong = await service.verifyCode(
        code: '000000',
        share: share,
        now: now.add(const Duration(minutes: 10)),
      );
      expect(wrong, isFalse);
    });

    test('verifyCode() từ chối khi phiên chia sẻ đã hết hạn (TTL 60 phút)',
        () async {
      final DateTime now = DateTime(2026, 11, 6, 20, 0, 0);
      final (code, share) = await service.createTripShare(now: now);

      // Đúng mã nhưng sau 61 phút → hết hạn
      final bool expired = await service.verifyCode(
        code: code,
        share: share,
        now: now.add(const Duration(minutes: 61)),
      );
      expect(expired, isFalse);
    });

    test('remainingSecondsAt() đếm ngược chính xác và trả về 0 khi quá hạn',
        () async {
      final DateTime now = DateTime(2026, 11, 6, 20, 0, 0);
      final (_, share) = await service.createTripShare(now: now);

      expect(share.remainingSecondsAt(now), 3600);
      expect(
        share.remainingSecondsAt(now.add(const Duration(minutes: 30))),
        1800,
      );
      expect(
        share.remainingSecondsAt(now.add(const Duration(minutes: 65))),
        0,
      );
    });

    test('TripShare model toJson / fromJson round-trip bảo toàn dữ liệu', () {
      final share = TripShare(
        codeHash: 'abcdef0123456789',
        createdAt: DateTime(2026, 11, 6, 20, 0, 0),
        expiresAt: DateTime(2026, 11, 6, 21, 0, 0),
        tripId: 'trip-999',
      );

      final json = share.toJson();
      final restored = TripShare.fromJson(json);

      expect(restored.codeHash, share.codeHash);
      expect(restored.createdAt, share.createdAt);
      expect(restored.expiresAt, share.expiresAt);
      expect(restored.tripId, share.tripId);
    });
  });
}
