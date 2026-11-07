import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/trip_share_service.dart';

/// Ngưỡng thời gian thực trên mobile: mọi thao tác mật mã phải < 10ms.
const double _maxAverageMs = 10.0;

/// Số vòng lặp đo lường (100–500 theo yêu cầu).
const int _iterations = 300;

/// Kết quả đo của một thao tác mật mã.
class BenchResult {
  const BenchResult(this.name, this.totalMs, this.iterations);

  final String name;
  final double totalMs;
  final int iterations;

  double get averageMs => totalMs / iterations;

  double get opsPerSecond =>
      averageMs <= 0 ? 0 : (iterations / totalMs) * 1000.0;
}

void main() {
  group('M6 Crypto benchmark', () {
    late CryptoService crypto;
    late TripShareService tripShare;

    setUp(() {
      crypto = CryptoService();
      tripShare = TripShareService(cryptoService: crypto);
    });

    test('đo hiệu năng ECDH/X25519, AES-256-GCM và SHA-256', () async {
      final List<BenchResult> results = <BenchResult>[];

      // ---- 1. Thỏa thuận khóa ECDH / X25519 ----
      final alice = await crypto.generateKeyPairX25519();
      final bob = await crypto.generateKeyPairX25519();
      final bobPublic = await crypto.importPublicKey(
        await crypto.exportPublicKey(bob),
      );

      // Warm-up: loại bỏ chi phí khởi tạo (JIT + plugin cryptography).
      await crypto.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: bobPublic,
      );

      final swEcdh = Stopwatch()..start();
      for (int i = 0; i < _iterations; i++) {
        await crypto.deriveSharedKey(
          myKeyPair: alice,
          theirPublicKey: bobPublic,
        );
      }
      swEcdh.stop();
      results.add(BenchResult('ECDH X25519 (deriveSharedKey)',
          swEcdh.elapsedMicroseconds / 1000.0, _iterations));

      // ---- 2. AES-256-GCM: mã hóa payload vị trí SOS ----
      final shared = await crypto.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: bobPublic,
      );
      await crypto.encryptLocationPayload(
        lat: 21.0285,
        lng: 105.8542,
        key: shared,
      );

      final swEnc = Stopwatch()..start();
      for (int i = 0; i < _iterations; i++) {
        await crypto.encryptLocationPayload(
          lat: 21.0285,
          lng: 105.8542,
          key: shared,
        );
      }
      swEnc.stop();
      results.add(BenchResult('AES-256-GCM encrypt (vị trí SOS)',
          swEnc.elapsedMicroseconds / 1000.0, _iterations));

      // ---- 3. AES-256-GCM: giải mã payload vị trí SOS ----
      final String encrypted =
          await crypto.encryptLocationPayload(
        lat: 21.0285,
        lng: 105.8542,
        key: shared,
      );

      final swDec = Stopwatch()..start();
      for (int i = 0; i < _iterations; i++) {
        await crypto.decryptLocationPayload(
          encryptedBase64: encrypted,
          key: shared,
        );
      }
      swDec.stop();
      results.add(BenchResult('AES-256-GCM decrypt (vị trí SOS)',
          swDec.elapsedMicroseconds / 1000.0, _iterations));

      // ---- 4. SHA-256 mã chia sẻ hành trình 6 chữ số ----
      await tripShare.hashTripCode('123456');

      final swSha = Stopwatch()..start();
      for (int i = 0; i < _iterations; i++) {
        await tripShare.hashTripCode('123456');
      }
      swSha.stop();
      results.add(
          BenchResult('SHA-256 (mã chia sẻ 6 số)', swSha.elapsedMicroseconds / 1000.0,
              _iterations));

      // ---- In bảng kết quả ----
      final buffer = StringBuffer()
        ..writeln('')
        ..writeln('=' * 78)
        ..writeln('  BẢNG BENCHMARK MẬT MÃ — MILESTONE 6 ($_iterations vòng lặp)')
        ..writeln('=' * 78)
        ..writeln('${'Thao tác'.padRight(36)}${'TB (ms)'.padLeft(12)}'
            '${'Tổng (ms)'.padLeft(14)}${'ops/s'.padLeft(12)}')
        ..writeln('-' * 78);
      for (final r in results) {
        buffer.writeln('${r.name.padRight(36)}'
            '${r.averageMs.toStringAsFixed(4).padLeft(12)}'
            '${r.totalMs.toStringAsFixed(2).padLeft(14)}'
            '${r.opsPerSecond.toStringAsFixed(0).padLeft(12)}');
      }
      buffer
        ..writeln('-' * 78)
        ..writeln('Ngưỡng an toàn thời gian thực: mỗi thao tác < '
            '$_maxAverageMs ms')
        ..writeln('=' * 78);
      // ignore: avoid_print
      print(buffer.toString());

      // ---- Assert: mọi thao tác đều dưới ngưỡng 10ms ----
      for (final r in results) {
        expect(r.averageMs, lessThan(_maxAverageMs),
            reason: '${r.name} vượt ngưỡng ${_maxAverageMs}ms');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('thời gian mã hóa/giải mã tin nhắn chat E2EE < 10ms', () async {
      final alice = await crypto.generateKeyPairX25519();
      final bob = await crypto.generateKeyPairX25519();
      final shared = await crypto.deriveSharedKey(
        myKeyPair: alice,
        theirPublicKey: await crypto.importPublicKey(
          await crypto.exportPublicKey(bob),
        ),
      );
      final Uint8List key = Uint8List.fromList(await shared.extractBytes());

      const plaintext = 'Con ơi, con về nhà chưa?';
      final payload = await crypto.encryptTextMessage(plaintext, key);

      final sw = Stopwatch()..start();
      for (int i = 0; i < _iterations; i++) {
        await crypto.decryptTextMessage(payload, key);
      }
      sw.stop();

      final double avgMs = sw.elapsedMicroseconds / 1000.0 / _iterations;
      // ignore: avoid_print
      print('AES-256-GCM chat decrypt: TB ${avgMs.toStringAsFixed(4)}ms '
          '($_iterations vòng lặp)');

      expect(avgMs, lessThan(_maxAverageMs));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
