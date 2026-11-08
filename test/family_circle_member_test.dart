import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sos_safe_family/core/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Family Circle & Dynamic Members Management Tests', () {
    test('Danh sách thành viên ban đầu hoàn toàn rỗng (đã xóa mặc định)', () {
      final appState = AppState();
      expect(appState.familyMembers, isEmpty);
    });

    test('sendInvitation gửi lời mời và khóa vị trí cho đến khi đối phương chấp thuận', () {
      final appState = AppState();

      appState.sendInvitation(
        name: 'Phạm Nguyên Vũ',
        relation: 'Anh em',
        email: 'vu.ct070165@kma.edu.vn',
      );

      expect(appState.familyMembers.length, 1);
      final member = appState.familyMembers.first;
      expect(member.name, 'Phạm Nguyên Vũ');
      expect(member.relation, 'Anh em');
      expect(member.email, 'vu.ct070165@kma.edu.vn');
      expect(member.initial, 'P');
      expect(member.isPendingOutgoing, isTrue);
      expect(member.isAccepted, isFalse); // Chưa chấp thuận -> Vị trí bị ẩn!

      // Kiểm tra Audit Log bảo mật
      expect(appState.auditLogs, isNotEmpty);
      expect(appState.auditLogs.first, contains('LỜI MỜI GỬI ĐI'));
      expect(appState.auditLogs.first, contains('Vị trí bị khóa'));

      // Đối phương chấp thuận (Two-way Handshake)
      appState.simulatePeerApproval(member.id);
      expect(appState.familyMembers.first.isAccepted, isTrue);
      expect(appState.auditLogs.first, contains('XÁC THỰC HAI CHIỀU'));
    });

    test('receiveIncomingInvitation nhận lời mời và cho phép từ chối hoặc chấp thuận', () {
      final appState = AppState();

      appState.receiveIncomingInvitation(
        name: 'Đỗ Văn Tuấn',
        relation: 'Bạn bè',
      );

      expect(appState.familyMembers.length, 1);
      final req = appState.familyMembers.first;
      expect(req.isPendingIncoming, isTrue);
      expect(req.isAccepted, isFalse);

      // Từ chối chia sẻ vị trí
      appState.rejectInvitation(req.id);
      expect(appState.familyMembers, isEmpty);
      expect(appState.auditLogs.first, contains('TỪ CHỐI ỦY QUYỀN'));
    });

    test('addFamilyMember nhiều thành viên và tự động cấp màu sắc & tọa độ', () {
      final appState = AppState();

      appState.addFamilyMember(
        name: 'Phạm Nguyên Vũ',
        relation: 'Bạn bè',
      );
      appState.addFamilyMember(
        name: 'Đỗ Văn Tuấn',
        relation: 'Đồng đội',
      );

      expect(appState.familyMembers.length, 2);
      expect(appState.familyMembers[0].name, 'Phạm Nguyên Vũ');
      expect(appState.familyMembers[1].name, 'Đỗ Văn Tuấn');
      // Màu sắc khác nhau
      expect(
        appState.familyMembers[0].avatarColor !=
            appState.familyMembers[1].avatarColor,
        isTrue,
      );
    });

    test('toggleMemberSharing thay đổi trạng thái chia sẻ vị trí', () {
      final appState = AppState();

      appState.addFamilyMember(
        name: 'Nguyên Vũ',
        relation: 'Bạn bè',
      );
      final memberId = appState.familyMembers.first.id;

      expect(appState.familyMembers.first.isSharing, isTrue);

      appState.toggleMemberSharing(memberId, false);
      expect(appState.familyMembers.first.isSharing, isFalse);
      expect(appState.auditLogs.first, contains('Tắt chia sẻ vị trí'));

      appState.toggleMemberSharing(memberId, true);
      expect(appState.familyMembers.first.isSharing, isTrue);
      expect(appState.auditLogs.first, contains('Bật chia sẻ vị trí'));
    });

    test('removeFamilyMember xóa thành viên khỏi danh sách', () {
      final appState = AppState();

      appState.addFamilyMember(name: 'Vũ', relation: 'Bạn');
      appState.addFamilyMember(name: 'Tuấn', relation: 'Bạn');
      expect(appState.familyMembers.length, 2);

      final vuId = appState.familyMembers.first.id;
      appState.removeFamilyMember(vuId);

      expect(appState.familyMembers.length, 1);
      expect(appState.familyMembers.first.name, 'Tuấn');
      expect(appState.auditLogs.first, contains('Đã ngắt kết nối thành viên "Vũ"'));
    });

    test('FamilyMemberItem copyWith hoạt động chính xác', () {
      const item = FamilyMemberItem(
        id: 'id-1',
        name: 'Tùng',
        relation: 'Tôi',
        avatarColor: Color(0xFF1E88E5),
        location: LatLng(21.0, 105.0),
      );

      final updated = item.copyWith(isSharing: false, battery: 99);
      expect(updated.id, 'id-1');
      expect(updated.name, 'Tùng');
      expect(updated.isSharing, isFalse);
      expect(updated.battery, 99);
    });
  });
}
