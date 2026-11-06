import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sos_safe_family/main.dart';

void main() {
  testWidgets('App renders the bottom navigation and main screens',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SOSFamilyApp());
    await tester.pump();

    // Thanh điều hướng dưới với 3 mục: Bản đồ / Vòng tròn / Bảo mật.
    expect(find.text('Bản đồ'), findsOneWidget);
    expect(find.text('Vòng tròn'), findsOneWidget);
    expect(find.text('Bảo mật'), findsOneWidget);

    // Nút SOS nổi bật.
    expect(find.byIcon(Icons.sos), findsOneWidget);
  });

  testWidgets('Tapping the SOS button requires a long press',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SOSFamilyApp());
    await tester.pump();

    // Chạm ngắn không được mở hộp thoại cảnh báo.
    await tester.tap(find.byIcon(Icons.sos));
    await tester.pump();
    expect(find.text('Cảnh báo SOS'), findsNothing);

    // Giữ đủ lâu (≥ 2 giây) thì mở hộp thoại — dùng gesture thủ công vì
    // tester.longPress chỉ giữ 500ms, không đủ thời gian chờ Timer.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.sos)),
    );
    await tester.pump(const Duration(seconds: 3));
    await gesture.up();
    await tester.pump();
    expect(find.text('Cảnh báo SOS'), findsOneWidget);
  });
}
