import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';

void main() {
  test('fake member ids are rejected while real Firebase UIDs are kept', () {
    final appState = AppState();

    appState.addFamilyMember(
      name: 'Người lạ',
      relation: 'Khác',
      email: 'bad@example.com',
      uid: 'uid_bad_example_com',
      status: MemberConnectionStatus.accepted,
    );
    expect(appState.familyMembers, isEmpty,
        reason: 'member.id giả được sinh từ email không được chấp nhận');

    appState.addFamilyMember(
      name: 'Người thân',
      relation: 'Chị em',
      email: 'good@example.com',
      uid: 'Z9fY2c3L7uQ4pKx1J8mN',
      status: MemberConnectionStatus.accepted,
    );

    expect(appState.familyMembers, hasLength(1));
    expect(appState.familyMembers.first.id, equals('Z9fY2c3L7uQ4pKx1J8mN'));
  });

  test('acceptInvitation matches only the exact peer invitation doc in mock Firestore data', () {
    final docs = <Map<String, dynamic>>[
      {'toEmail': 'me@example.com', 'fromUid': 'peer_uid_2', 'status': 'pending'},
      {'toEmail': 'me@example.com', 'fromUid': 'peer_uid_1', 'status': 'pending'},
      {'fromUid': 'my_uid_1', 'toUid': 'peer_uid_1', 'status': 'pending'},
      {'fromUid': 'my_uid_1', 'toUid': 'peer_uid_9', 'status': 'pending'},
    ];

    final matches = docs.where((doc) {
      return AppState.matchesInvitationForAcceptance(
        doc,
        currentUserEmail: 'me@example.com',
        currentUserUid: 'my_uid_1',
        targetId: 'peer_uid_1',
      );
    }).toList();

    expect(matches, hasLength(2));
    expect(matches.any((doc) => doc['fromUid'] == 'peer_uid_1'), isTrue);
    expect(matches.any((doc) => doc['toUid'] == 'peer_uid_1'), isTrue);
  });
}
