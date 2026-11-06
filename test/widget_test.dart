import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sos_safe_family/main.dart';

/// Giữ nút SOS cho đến khi màn hình đếm ngược hiện ra rồi nhả tay.
///
/// GestureDetector bắt đầu "long press" sau ~500ms giữ; bộ đếm 2 giây kích
/// hoạt dialog khi tổng thời gian giữ ≈ 2,5s. Pump theo từng 200ms để không
/// phụ thuộc chính xác giờ.
Future<void> openSosCountdown(WidgetTester tester) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.byIcon(Icons.sos)));
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (tester.any(find.text('CHẾ ĐỘ KHẨN CẤP SẮP KÍCH HOẠT'))) break;
  }
  await tester.pump();
  expect(find.text('CHẾ ĐỘ KHẨN CẤP SẮP KÍCH HOẠT'), findsOneWidget);
  await gesture.up();
}

/// Đợi cho đến khi banner khẩn cấp hiện (chống pumpAndSettle vô hạn do
/// animation pulse lặp lại trong dialog).
Future<void> waitUntil(WidgetTester tester, Finder finder,
    {int maxPumps = 40}) async {
  for (int i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (tester.any(finder)) return;
  }
  expect(finder, findsWidgets);
}

void main() {
  testWidgets('App renders the bottom navigation and main screens',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SOSFamilyApp());
    await tester.pump();

    // Thanh điều hướng dưới với các mục: Bản đồ / Vòng tròn / Cá nhân.
    expect(find.text('Bản đồ'), findsOneWidget);
    expect(find.text('Vòng tròn'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);

    // Chạm vào mục Cá nhân để kiểm tra có mục Bảo mật
    await tester.tap(find.text('Cá nhân'));
    await tester.pump();
    expect(find.text('Bảo mật'), findsOneWidget);

    // Nút SOS nổi bật.
    expect(find.byIcon(Icons.sos), findsOneWidget);
  });

  testWidgets('Tapping the SOS button requires a long press',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SOSFamilyApp());
    await tester.pump();

    // Chạm ngắn không được mở màn hình đếm ngược.
    await tester.tap(find.byIcon(Icons.sos));
    await tester.pump();
    expect(find.text('CHẾ ĐỘ KHẨN CẤP SẮP KÍCH HOẠT'), findsNothing);

    // Giữ đủ lâu (≥ 2,5s) thì mở màn hình đếm ngược.
    await openSosCountdown(tester);
    expect(find.text('CHẾ ĐỘ KHẨN CẤP SẮP KÍCH HOẠT'), findsOneWidget);
  });

  testWidgets('Countdown shows 3-2-1 and HỦY', (WidgetTester tester) async {
    await tester.pumpWidget(const SOSFamilyApp());
    await tester.pump();

    await openSosCountdown(tester);

    // Đếm ngược bắt đầu ở 3.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('HỦY'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);

    // Bấm HỦY đóng màn hình, không kích hoạt khẩn cấp.
    await tester.tap(find.text('HỦY'));
    // Pump nhiều nhịp để animation đóng dialog hoàn tất (dialog tồn tại trong
    // cây widget cho tới khi animation reverse kết thúc).
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('CHẾ ĐỘ KHẨN CẤP SẮP KÍCH HOẠT'), findsNothing);
    expect(find.text('TRẠNG THÁI KHẨN CẤP ĐANG BẬT'), findsNothing);
  });

  testWidgets('Countdown completing activates the emergency banner',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SOSFamilyApp());
    await tester.pump();

    await openSosCountdown(tester);

    // 3 → 2 → 1 → kích hoạt (mỗi lần một nhịp 1s).
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await waitUntil(tester, find.text('TRẠNG THÁI KHẨN CẤP ĐANG BẬT'));

    expect(find.text('TRẠNG THÁI KHẨN CẤP ĐANG BẬT'), findsOneWidget);
    expect(find.text('TÔI ĐÃ AN TOÀN'), findsOneWidget);
  });

  testWidgets('"TÔI ĐÃ AN TOÀN" resolves the emergency state',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SOSFamilyApp());
    await tester.pump();

    await openSosCountdown(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await waitUntil(tester, find.text('TRẠNG THÁI KHẨN CẤP ĐANG BẬT'));
    expect(find.text('TRẠNG THÁI KHẨN CẤP ĐANG BẬT'), findsOneWidget);

    // Bấm xác nhận an toàn → banner biến mất.
    await tester.tap(find.text('TÔI ĐÃ AN TOÀN'));
    await tester.pump();
    expect(find.text('TRẠNG THÁI KHẨN CẤP ĐANG BẬT'), findsNothing);
  });

  testWidgets('Bản đồ hiển thị vùng an toàn và danh sách vùng',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SOSFamilyApp());
    await tester.pump();

    // Lớp vòng tròn geofence được vẽ trên bản đồ.
    expect(find.byType(CircleLayer), findsOneWidget);

    // Nút mở danh sách vùng an toàn.
    final geofenceBtn = find.byWidgetPredicate(
      (w) => w is FloatingActionButton && w.heroTag == 'geofence_list_btn',
    );
    expect(geofenceBtn, findsOneWidget);

    await tester.tap(geofenceBtn);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // BottomSheet hiển thị 2 vùng mẫu.
    expect(find.text('Vùng an toàn'), findsOneWidget);
    expect(find.text('Nhà riêng'), findsOneWidget);
    expect(find.text('Cơ quan / Trường học'), findsOneWidget);
  });
}
