# Báo cáo thiết kế giao diện UI mock

- Tạo file giao diện chính: `lib/main.dart`
- Màn hình 1: `MainScreen` (BottomNavigationBar + FAB SOS giữ 2 giây)
- Màn hình 2: `MapScreen` (FlutterMap + OpenStreetMap + Marker mock Hà Nội)
- Màn hình 3: `CircleScreen` (vòng tròn gia đình + consent + mã mời 6 số)
- Màn hình 4: `SecurityScreen` (khóa vân tay + chống chụp + audit log mock)
- Không gọi Firebase, không cần backend, dữ liệu mock hoàn toàn độc lập

Kết quả kiểm tra:
- `flutter analyze`: No issues found! (trên bản sao project ở đường dẫn an toàn)
- `flutter build apk --debug`: Built build/app/outputs/flutter-apk/app-debug.apk
- Trạng thái nghiệm thu: ĐẠT
- Lưu ý: đường dẫn gốc workspace có ký tự tiếng Việt gây lỗi analyzer của Flutter SDK; đã kiểm tra bằng bản sao project ở đường dẫn ASCII an toàn nhưng nội dung code và build đều đạt yêu cầu
