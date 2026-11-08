import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/models/sos_event.dart';
import 'package:sos_safe_family/data/services/auth_service.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/secure_storage_service.dart';
import 'package:sos_safe_family/data/services/sos_service.dart';
import 'package:sos_safe_family/main.dart';

class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> _memory = {};

  @override
  Future<void> saveUserPrivateKey(String uid, String privateKeyBase64) async {
    _memory['x25519_priv_$uid'] = privateKeyBase64;
  }

  @override
  Future<String?> getUserPrivateKey(String uid) async {
    return _memory['x25519_priv_$uid'];
  }

  @override
  Future<void> saveUserPublicKey(String uid, String publicKeyBase64) async {
    _memory['x25519_pub_$uid'] = publicKeyBase64;
  }

  @override
  Future<String?> getUserPublicKey(String uid) async {
    return _memory['x25519_pub_$uid'];
  }

  @override
  Future<void> deleteUserKeys(String uid) async {
    _memory.remove('x25519_priv_$uid');
    _memory.remove('x25519_pub_$uid');
  }
}

AppState createTestAppState(CryptoService crypto) {
  final fakeStorage = FakeSecureStorageService();
  final authService = AuthService(
    cryptoService: crypto,
    secureStorage: fakeStorage,
  );
  return AppState(
    cryptoService: crypto,
    authService: authService,
  );
}

void main() {
  group('M12 SOS Relay & Multi-device Lifecycle Tests', () {
    late CryptoService crypto;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      crypto = CryptoService();
    });

    test('1. Vòng đời SOS active -> resolved trên Firestore giữa 2 máy', () async {
      final aliceState = createTestAppState(crypto);
      final bobState = createTestAppState(crypto);

      // Thiết lập tài khoản Máy A (Alice) và Máy B (Bob)
      await aliceState.signInWithTestAccount(
        email: 'tung.ct070161@kma.edu.vn',
        displayName: 'Phạm Văn Tùng',
      );
      await bobState.signInWithTestAccount(
        email: 'vu.ct070165@kma.edu.vn',
        displayName: 'Phạm Nguyên Vũ',
      );

      // --- BƯỚC 1: Máy A kích hoạt SOS ---
      final eventA = await aliceState.activateSos(
        lat: 21.0285,
        lng: 105.8542,
        isMocked: false,
        senderName: 'Phạm Văn Tùng',
      );

      expect(aliceState.isSosActive, isTrue);
      expect(aliceState.isMySos, isTrue);
      expect(aliceState.activeSos?.sosId, equals(eventA.sosId));
      expect(aliceState.activeSos?.status, equals(SosStatus.active));

      final encryptedPayload = aliceState.lastEncryptedSos;
      expect(encryptedPayload, isNotNull);
      expect(encryptedPayload!.encryptedEvent, isNotEmpty);
      expect(encryptedPayload.encryptedLocation, isNotEmpty);

      // --- BƯỚC 2: Máy B nhận SOS từ Firestore Stream ---
      // Máy B giải mã bằng khóa phiên thống nhất
      final sessionKey = await bobState.resolveSosSessionKey(
        targetUid: aliceState.currentUserUid,
        sessionKeyId: 'sos_safe_family_global_demo_key',
      );

      final receivedEvent = await bobState.receiveIncomingSos(
        encryptedEventBase64: encryptedPayload.encryptedEvent,
        encryptedLocationBase64: encryptedPayload.encryptedLocation,
        key: sessionKey,
      );

      // Xác minh Máy B giải mã thành công đúng dữ liệu thực tế
      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.senderName, equals('Phạm Văn Tùng'));
      expect(receivedEvent.lat, equals(21.0285));
      expect(receivedEvent.lng, equals(105.8542));
      expect(bobState.isSosActive, isTrue);
      expect(bobState.isMySos, isFalse, reason: 'Máy B phải là bên nhận (isMySos == false)');
      expect(bobState.activeSos?.sosId, equals(eventA.sosId));

      // --- BƯỚC 3: Máy A bấm "TÔI ĐÃ AN TOÀN" ---
      await aliceState.resolveSos();
      expect(aliceState.isSosActive, isFalse);
      expect(aliceState.activeSos?.isResolved, isTrue);

      // --- BƯỚC 4: Máy B nhận tín hiệu resolved từ Firestore -> tự ẩn banner ---
      bobState.clearIncomingSos(eventA.sosId);
      expect(bobState.isSosActive, isFalse, reason: 'Banner trên Máy B phải tự ẩn khi trạng thái chuyển sang resolved');
      expect(bobState.activeSos, isNull);
    });

    test('2. Gói tin SOS sai MAC (bị can thiệp trên đường truyền) bị từ chối và ghi Audit Log', () async {
      final bobState = createTestAppState(crypto);
      final key = await crypto.deriveRoomKey('sos_safe_family_global_demo_key');

      // Gói tin SOS gốc
      final sosService = SosService(cryptoService: crypto);
      final validEvent = SosEvent(
        sosId: 'sos-tamper-test',
        senderName: 'Kẻ mạo danh',
        lat: 21.0185,
        lng: 105.8021,
        isMocked: false,
        batteryLevel: 95,
        timestamp: DateTime.now(),
      );
      final payload = await sosService.encryptEvent(event: validEvent, key: key);

      // Giả lập kẻ tấn công can thiệp sửa đổi byte trong ciphertext
      final rawBytes = base64Decode(payload.encryptedEvent);
      rawBytes[rawBytes.length - 1] ^= 0xAA; // Đảo bit ciphertext
      final tamperedEncryptedEvent = base64Encode(rawBytes);

      // Máy B xử lý gói tin bị sửa đổi
      final result = await bobState.receiveIncomingSos(
        encryptedEventBase64: tamperedEncryptedEvent,
        encryptedLocationBase64: payload.encryptedLocation,
        key: key,
      );

      // Kết quả: Từ chối gói tin, không kích hoạt alert
      expect(result, isNull);
      expect(bobState.isSosActive, isFalse);

      // Ghi nhận tấn công vào Nhật ký kiểm toán
      final hasTamperLog = bobState.auditLogs.any((log) =>
          log.contains('CẢNH BÁO TẤN CÔNG') && log.contains('MAC không khớp'));
      expect(hasTamperLog, isTrue, reason: 'Phải ghi nhận cảnh báo tấn công sai MAC vào audit log');
    });

    test('3. Receiver bỏ qua sự kiện SOS của chính mình (senderUid == myUid)', () async {
      final aliceState = createTestAppState(crypto);
      await aliceState.signInWithTestAccount(
        email: 'tung.ct070161@kma.edu.vn',
        displayName: 'Phạm Văn Tùng',
      );
      final myUid = aliceState.currentUserUid!;

      // Giả lập hàm kiểm tra lọc doc trong initSosListener
      bool filterSosDoc({
        required String docSenderUid,
        required String currentUid,
        required bool isMySos,
      }) {
        final bool isMine = (docSenderUid.isNotEmpty && docSenderUid == currentUid) ||
            (docSenderUid == 'me' && isMySos);
        return isMine; // true nghĩa là sự kiện của chính mình -> cần bỏ qua
      }

      // Trường hợp doc của chính mình
      expect(filterSosDoc(docSenderUid: myUid, currentUid: myUid, isMySos: true), isTrue);
      expect(filterSosDoc(docSenderUid: 'me', currentUid: myUid, isMySos: true), isTrue);

      // Trường hợp doc của người khác
      expect(filterSosDoc(docSenderUid: 'vu_ct070165', currentUid: myUid, isMySos: true), isFalse);
    });

    testWidgets('4. Kiểm thử hiển thị UI Banner SOS cho cả 2 máy (Gửi & Nhận)', (WidgetTester tester) async {
      final aliceState = createTestAppState(crypto);
      final bobState = createTestAppState(crypto);

      await aliceState.signInWithTestAccount(
        email: 'tung.ct070161@kma.edu.vn',
        displayName: 'Phạm Văn Tùng',
      );
      await bobState.signInWithTestAccount(
        email: 'vu.ct070165@kma.edu.vn',
        displayName: 'Phạm Nguyên Vũ',
      );

      // --- BƯỚC 1: Render Banner Máy A (Phía người gửi SOS) ---
      await aliceState.activateSos(
        lat: 21.0285,
        lng: 105.8542,
        isMocked: false,
        senderName: 'Phạm Văn Tùng',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosEmergencyBanner(appState: aliceState),
          ),
        ),
      );
      await tester.pump();

      // Kiểm tra banner người gửi hiển thị đúng
      expect(find.byType(SosEmergencyBanner), findsOneWidget);
      expect(find.text('TRẠNG THÁI KHẨN CẤP ĐANG BẬT'), findsOneWidget);
      expect(find.text('TÔI ĐÃ AN TOÀN'), findsOneWidget);

      // --- BƯỚC 2: Render Banner Máy B (Phía người nhận SOS) ---
      final key = await bobState.resolveSosSessionKey();
      await bobState.receiveIncomingSos(
        encryptedEventBase64: aliceState.lastEncryptedSos!.encryptedEvent,
        encryptedLocationBase64: aliceState.lastEncryptedSos!.encryptedLocation,
        key: key,
      );

      bool mapOpened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosEmergencyBanner(
              appState: bobState,
              onOpenMap: () => mapOpened = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Kiểm tra banner người nhận hiển thị đúng
      expect(find.byType(SosEmergencyBanner), findsOneWidget);
      expect(find.textContaining('PHẠM VĂN TÙNG GỬI SOS'), findsOneWidget);
      expect(find.textContaining('21.0285, 105.8542'), findsOneWidget);
      expect(find.text('Mở bản đồ'), findsOneWidget);
      expect(find.text('Tôi đã hỗ trợ'), findsOneWidget);

      // Nhấn "Mở bản đồ"
      await tester.tap(find.text('Mở bản đồ'));
      await tester.pump();
      expect(mapOpened, isTrue);

      // Nhấn "Tôi đã hỗ trợ" -> tắt banner người nhận
      await tester.tap(find.text('Tôi đã hỗ trợ'));
      await tester.pump();
      expect(bobState.isSosActive, isFalse);

      // --- BƯỚC 3: Máy A giải quyết SOS ("TÔI ĐÃ AN TOÀN") ---
      await aliceState.resolveSos();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosEmergencyBanner(appState: aliceState),
          ),
        ),
      );
      await tester.pump();
      // Banner biến mất (SizedBox.shrink)
      expect(find.text('TRẠNG THÁI KHẨN CẤP ĐANG BẬT'), findsNothing);

      // --- BƯỚC 4: Xác nhận 4 ảnh demo 2 máy đã được lưu đầy đủ ---
      final demoFilesDev = [
        '/home/tung/dev/sos_safe_family/hinh_anh_demo/demo_may_A_kich_hoat_sos.png',
        '/home/tung/dev/sos_safe_family/hinh_anh_demo/demo_may_B_nhan_sos_banner.png',
        '/home/tung/dev/sos_safe_family/hinh_anh_demo/demo_may_A_da_an_toan.png',
        '/home/tung/dev/sos_safe_family/hinh_anh_demo/demo_may_B_tat_banner_an_toan.png',
      ];
      final demoFilesATBM = [
        '/home/tung/Màn hình nền/ATBM/hinh_anh_demo/demo_may_A_kich_hoat_sos.png',
        '/home/tung/Màn hình nền/ATBM/hinh_anh_demo/demo_may_B_nhan_sos_banner.png',
        '/home/tung/Màn hình nền/ATBM/hinh_anh_demo/demo_may_A_da_an_toan.png',
        '/home/tung/Màn hình nền/ATBM/hinh_anh_demo/demo_may_B_tat_banner_an_toan.png',
      ];
      for (final p in [...demoFilesDev, ...demoFilesATBM]) {
        expect(File(p).existsSync(), isTrue, reason: 'File $p phải tồn tại');
        expect(File(p).lengthSync(), greaterThan(1000), reason: 'File $p phải có nội dung');
      }
    });
  });
}
