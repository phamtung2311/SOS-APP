import 'package:flutter_test/flutter_test.dart';
import 'package:sos_safe_family/core/app_state.dart';

void main() {
  test('same peer pair derives the same SOS key regardless of ordering', () async {
    final appState = AppState();

    final forward = await appState.resolveSosSessionKey(
      sessionKeyId: 'circle_abc123___xyz789',
    );
    final reverse = await appState.resolveSosSessionKey(
      sessionKeyId: 'circle_xyz789___abc123',
    );

    expect(forward, equals(reverse),
        reason: 'cùng một cặp peer phải có cùng khóa phiên dù gọi theo thứ tự ngược');
  });
}
