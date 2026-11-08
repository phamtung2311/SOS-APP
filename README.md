# sos_safe_family

A new Flutter project for SOS Safe Family — An toàn gia đình.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deploy Firestore Rules

Hệ thống sử dụng file cấu hình bảo mật `firestore.rules` để thực thi quyền kiểm soát truy cập (Access Control) cấp tài liệu theo nguyên tắc Zero-Knowledge.

Để triển khai quy tắc bảo mật lên Firebase Cloud Firestore của dự án:

```bash
# 1. Đăng nhập vào Firebase CLI (nếu chưa đăng nhập)
firebase login

# 2. Triển khai riêng Firestore Security Rules mà không ảnh hưởng tới các dịch vụ khác
firebase deploy --only firestore:rules
```
