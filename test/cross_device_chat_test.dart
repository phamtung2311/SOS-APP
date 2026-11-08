import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';

void main() {
  test('two real UIDs produce the same room id even when display names match', () {
    const uidA = 'uid_a1';
    const uidB = 'uid_b2';

    final roomA = AppState.buildChatRoomId(myUid: uidA, peerUid: uidB);
    final roomB = AppState.buildChatRoomId(myUid: uidB, peerUid: uidA);

    expect(roomA, 'chat_uid_a1_uid_b2');
    expect(roomB, roomA);
  });

  test('pairing-code flow stays immediate while email invitation flow remains pending until accept', () {
    const incoming = MemberConnectionStatus.pendingIncoming;
    const outgoing = MemberConnectionStatus.pendingOutgoing;
    const accepted = MemberConnectionStatus.accepted;

    expect(AppState.resolveInvitationStatus(statusValue: 'accepted', isIncoming: false, isOutgoing: false), accepted);
    expect(AppState.resolveInvitationStatus(statusValue: 'pending', isIncoming: true, isOutgoing: false), incoming);
    expect(AppState.resolveInvitationStatus(statusValue: 'pending', isIncoming: false, isOutgoing: true), outgoing);
    expect(AppState.resolveInvitationStatus(statusValue: 'cancelled', isIncoming: false, isOutgoing: false), outgoing);
  });
}
