# BC_M4_CryptoService_20261106

## Mục tiêu
Xây dựng module bảo mật offline cốt lõi cho ứng dụng SOS Safe Family, bao gồm:
- ECDH X25519
- HKDF SHA-256
- AES-GCM 256-bit
- lưu trữ khóa ở secure storage
- phát hiện GPS giả/mocking

## Kết quả thực hiện
- Đã triển khai `CryptoService` theo đúng API của package `cryptography` phiên bản 2.9.0.
- Sửa các mismatches chính:
  - dùng `extractPublicKey()` thay cho `keyPair.publicKey`
  - dùng `extractBytes()` thay cho `SecretKey.bytes`
  - dùng `nonce` thay cho `salt` trong `Hkdf.deriveKey`
  - dùng `Mac(data.sublist(...))` và `secretBox.mac.bytes`
  - import `dart:typed_data` và tạo nonce bằng vòng lặp thay vì `nextBytes`
- Đã cập nhật `SecureStorageService` để khớp với `flutter_secure_storage` 11.2.0 (loại bỏ `encryptedSharedPreferences` đã bị xoá khỏi API).

## Xác minh
- Chạy: `flutter test test/crypto_service_test.dart`
- Kết quả: `00:08 +4: All tests passed!`
- Chạy: `flutter analyze`
- Kết quả: `No issues found!`

## Trạng thái
- Module bảo mật offline hiện đã hoàn thiện và đạt chuẩn kiểm tra kỹ thuật.
- Dừng ở đây và chờ chỉ đạo tiếp theo.
