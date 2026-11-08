import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/models/sos_event.dart';
import 'package:sos_safe_family/data/services/sos_service.dart';
import 'package:sos_safe_family/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M13 Kiểm thử loại bỏ toàn bộ dữ liệu giả & mã mời thật', () {
    test('1. Thành viên mới không có toạ độ hoặc pin bịa (null)', () {
      final appState = AppState();

      // Gửi lời mời kết nối thành viên mới
      appState.sendInvitation(
        name: 'Phạm Nguyên Vũ',
        relation: 'Anh em',
        email: 'vu.ct070165@kma.edu.vn',
      );

      expect(appState.familyMembers.length, 1);
      final member = appState.familyMembers.first;

      // Xác minh tuyệt đối không còn tọa độ bịa hoặc pin bịa
      expect(member.location, isNull, reason: 'Không được tự sinh tọa độ quanh vị trí của mình');
      expect(member.battery, isNull, reason: 'Pin của đối phương phải là null khi chưa nhận dữ liệu thật');
      expect(member.lastUpdated, isNull, reason: 'lastUpdated không được hardcode chuỗi tĩnh');

      // Thêm thành viên trực tiếp với status accepted cũng không được tự sinh tọa độ/pin
      appState.addFamilyMember(
        name: 'Đỗ Văn Tuấn',
        relation: 'Bạn bè',
        status: MemberConnectionStatus.accepted,
      );

      final acceptedMember = appState.familyMembers.last;
      expect(acceptedMember.location, isNull);
      expect(acceptedMember.battery, isNull);
      expect(acceptedMember.lastUpdated, equals('Đã kết nối'));
    });

    test('2. Audit log ban đầu rỗng, không chứa placeholder giờ cố định', () {
      final appState = AppState();

      // Khi khởi tạo, danh sách auditLogs phải hoàn toàn rỗng
      expect(appState.auditLogs, isEmpty, reason: 'Không được có placeholder hệ thống sẵn sàng');

      // Kiểm tra caption phân loại sự kiện của AuditLogScreen
      expect(
        AuditLogScreen.auditSubtitle('10:00 - [MÔ PHỎNG] Chấp thuận kết nối'),
        contains('Mô phỏng (Simulation)'),
      );
      expect(
        AuditLogScreen.auditSubtitle('10:05 - [SOS] Nhận cảnh báo khẩn cấp'),
        contains('Sự kiện khẩn cấp SOS'),
      );
      expect(
        AuditLogScreen.auditSubtitle('10:10 - [TỪ CHỐI ỦY QUYỀN] Đã từ chối chia sẻ vị trí'),
        contains('Từ chối ủy quyền'),
      );
      expect(
        AuditLogScreen.auditSubtitle('10:15 - [ỦY QUYỀN VỊ TRÍ] Đã chấp thuận chia sẻ vị trí'),
        contains('Ủy quyền truy cập'),
      );
      expect(
        AuditLogScreen.auditSubtitle('10:20 - [MÃ MỜI] Đã tạo mã kết nối mới: 123456'),
        contains('Kết nối thành viên'),
      );
    });

    test('3. Nhập sai mã mời hoặc mã không tồn tại thì không tạo member', () async {
      final appState = AppState();
      final initialCount = appState.familyMembers.length;

      // Mã không đủ 6 số
      final invalidLen = await appState.connectWithPairingCode(code: '123');
      expect(invalidLen, isFalse);
      expect(appState.familyMembers.length, initialCount);

      // Mã 6 số nhưng không tồn tại trên Firestore
      final notFound = await appState.connectWithPairingCode(code: '999999');
      expect(notFound, isFalse);
      expect(appState.familyMembers.length, initialCount, reason: 'Mã không tồn tại không được tạo thành viên mới');
    });

    test('4. generatePairingCode sinh mã ngẫu nhiên 6 chữ số và lưu vào state', () async {
      final appState = AppState();

      expect(appState.myPairingCode, isNull);

      final code = await appState.generatePairingCode();
      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);
      expect(appState.myPairingCode, equals(code));

      // Sinh mã lần 2 phải cập nhật state
      final code2 = await appState.generatePairingCode();
      expect(code2.length, 6);
      expect(appState.myPairingCode, equals(code2));
    });

    testWidgets('5. Model SosEvent hỗ trợ pin null và hiển thị gạch ngang (—) trên UI', (WidgetTester tester) async {
      final appState = AppState();

      // Kích hoạt SOS với pin null
      final event = SosEvent(
        sosId: 'sos-null-battery-test',
        senderName: 'Phạm Văn Tùng',
        lat: 21.0285,
        lng: 105.8542,
        isMocked: false,
        batteryLevel: null,
        timestamp: DateTime.now(),
      );

      // toJson không chứa giá trị pin bịa
      final json = event.toJson();
      expect(json.containsKey('batteryLevel'), isFalse);

      // fromJson đọc lại đúng null
      final restored = SosEvent.fromJson(json);
      expect(restored.batteryLevel, isNull);

      // Mã hóa và nhận vào máy B để hiển thị banner phía người nhận
      final key = Uint8List.fromList(List<int>.filled(32, 1));
      final sosService = SosService();
      final payload = await sosService.encryptEvent(event: restored, key: key);
      await appState.receiveIncomingSos(
        encryptedEventBase64: payload.encryptedEvent,
        encryptedLocationBase64: payload.encryptedLocation,
        key: key,
      );

      // Render banner người nhận với event có pin null
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosEmergencyBanner(appState: appState),
          ),
        ),
      );
      await tester.pump();

      // Xác minh UI hiển thị dấu gạch ngang (—) thay vì pin giả
      expect(find.textContaining('Pin: —'), findsOneWidget);
    });
  });
}
