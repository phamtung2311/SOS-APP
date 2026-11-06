# ĐỀ CƯƠNG ĐỒ ÁN CUỐI KỲ

**Môn học:** An toàn và bảo mật trong phát triển ứng dụng di động
**Học viện Kỹ thuật Mật mã – Khoa Công nghệ Thông tin**

## ỨNG DỤNG SOS & AN TOÀN GIA ĐÌNH

*Theo dõi vị trí và cầu cứu khẩn cấp mã hóa đầu cuối trên thiết bị di động*

| Thông tin | Nội dung |
|---|---|
| Lớp | L03 |
| Nhóm | *(điền sau)* |
| Sinh viên thực hiện | *(điền sau)* |
| Người hướng dẫn | Thái Thị Thanh Vân |
| Năm thực hiện | 2025 |

---

## MỤC LỤC

1. [Mô tả đề tài và mục tiêu](#1-mô-tả-đề-tài-và-mục-tiêu)
2. [Phạm vi và các chức năng chính](#2-phạm-vi-và-các-chức-năng-chính)
3. [Cơ chế bảo mật tích hợp (điểm nhấn đồ án)](#3-cơ-chế-bảo-mật-tích-hợp-điểm-nhấn-đồ-án)
4. [Kiến trúc hệ thống và công nghệ sử dụng](#4-kiến-trúc-hệ-thống-và-công-nghệ-sử-dụng)
5. [Mô hình dữ liệu và giao thức truyền thông](#5-mô-hình-dữ-liệu-và-giao-thức-truyền-thông)
6. [Khung báo cáo và kế hoạch thực hiện](#6-khung-báo-cáo-và-kế-hoạch-thực-hiện)
7. [Kết quả kỳ vọng và tiêu chí đánh giá](#7-kết-quả-kỳ-vọng-và-tiêu-chí-đánh-giá)

---

## 1. MÔ TẢ ĐỀ TÀI VÀ MỤC TIÊU

### 1.1. Định hướng đề tài

Ứng dụng di động hỗ trợ an toàn cho gia đình: các thành viên theo dõi vị trí của nhau trong "vòng tròn an toàn", gửi cảnh báo SOS kèm vị trí và bản ghi âm khi có nguy cơ, cảnh báo khi người thân rời khỏi vùng an toàn, và chia sẻ hành trình tạm thời khi đi taxi/giao dịch.

Điểm khác biệt cốt lõi: **toàn bộ dữ liệu vị trí và nội dung cảnh báo được mã hóa đầu cuối (E2EE)** — máy chủ chỉ chuyển tiếp mã ciphertext, không thể đọc nội dung. Đây là điểm giáo viên đánh giá khác biệt so với các đồ án khác trong lớp (đa số chỉ bổ sung JWT và băm mật khẩu).

### 1.2. Mục tiêu

- Xây dựng ứng dụng Android hoàn chỉnh, hoạt động trên 2 thiết bị thật để demo hai chiều.
- Đảm bảo tính bí mật của dữ liệu vị trí: E2EE, khóa nằm trong Android Keystore, server không đọc được.
- Đảm bảo quyền kiểm soát của người dùng: consent có thể thu hồi, nhật ký minh bạch ai xem vị trí ai.
- Trình bày một mô hình bảo mật hoàn chỉnh (threat model) và đánh giá hiệu quả của từng cơ chế.

### 1.3. Đối tượng sử dụng và bối cảnh

Ứng dụng hướng đến các gia đình có người lớn, trẻ em, người cao tuổi hoặc người đi làm nguy hiểm — những người cần gia đình theo dõi và cần cầu cứu nhanh khi gặp nguy hiểm. Vấn đề mang tính thời sự thực tế tại Việt Nam, gắn với chủ đề an toàn thông tin trong ứng dụng di động.

---

## 2. PHẠM VI VÀ CÁC CHỨC NĂNG CHÍNH

### 2.1. Các chức năng

| # | Chức năng | Mô tả |
|---|---|---|
| 1 | Quản lý vòng tròn gia đình | Tạo vòng tròn, thêm/xóa thành viên, phân quyền xem vị trí (có xác thực 2 lớp) |
| 2 | Theo dõi vị trí thời gian thực | Hiển thị vị trí các thành viên trên bản đồ, cập nhật theo thời gian thực, có bật/tắt chia sẻ |
| 3 | Cảnh báo SOS | Nút SOS gửi cảnh báo tới toàn bộ thành viên kèm vị trí hiện tại và bản ghi âm/video ngắn tự động |
| 4 | Geofence vùng an toàn | Đặt vùng an toàn (nhà, trường, cơ quan); cảnh báo khi thành viên ra/vào vùng |
| 5 | Chia sẻ hành trình | Sinh mã 6 chữ số có thời hạn để người khác theo dõi hành trình trong thời gian ngắn (đi taxi, giao dịch) |
| 6 | Nhật ký và lịch sử | Lưu lịch sử vị trí và cảnh báo trong ngày, cho phép tra cứu |
| 7 | Quản lý tài khoản | Đăng ký/đăng nhập, đổi mật khẩu, đăng xuất, cài đặt bảo mật |

### 2.2. Phạm vi giới hạn (để kiểm soát tiến độ)

- Không làm liveness detection tự viết — dùng Face ID/Touch ID native.
- Geofence dùng khoảng cách Euclid trên bán kính vòng tròn, không dùng đa giác.
- Không làm bản đồ offline; phụ thuộc dịch vụ bản đồ online.
- Không triển khai trên App Store, chỉ chạy APK cài trực tiếp.
- Chỉ hỗ trợ Android (mục tiêu tối thiểu Android 10).

### 2.3. Yêu cầu phi chức năng

- Cập nhật vị trí trong vòng 5–10 giây, không làm tụt pin.
- Hoạt động nền ổn định, có thông báo khi có SOS.
- Cơ sở dữ liệu cục bộ mã hóa, không lưu plaintext vị trí trên thiết bị.
- Giao diện tiếng Việt, hỗ trợ màn hình nhỏ.

---

## 3. CƠ CHẾ BẢO MẬT TÍCH HỢP (ĐIỂM NHẤN ĐỒ ÁN)

> Chương này là trọng tâm lý thuyết của đồ án. Mỗi cơ chế dưới đây đều phải có phân tích **"đe dọa gì – chống được gì – còn hạn chế gì"**.

### 3.1. Bảo mật dữ liệu vị trí và nội dung SOS

- Mã hóa đầu cuối (E2EE): X25519 để trao đổi khóa, AES-256-GCM để mã hóa payload vị trí, tin SOS, bản ghi âm.
- Máy chủ chỉ làm relay, lưu ciphertext; mỗi thiết bị giữ private key trong Android Keystore (hardware-backed).
- Mỗi thành viên có một cặp khóa công khai; khóa được đăng ký và xác minh chữ ký khi kết nối lần đầu.
- Chống giả mạo vị trí: kiểm tra mock location provider, độ trôi GPS bất thường, cảnh báo trong nhật ký an toàn.

### 3.2. Quản lý phiên và xác thực

- Firebase Authentication (email + OTP) cấp JWT; access token ngắn hạn, refresh token có thời hạn và thu hồi được.
- Token lưu trong Android Keystore, không lưu dạng plaintext trong SharedPreferences.
- Xác thực 2 lớp (OTP) khi thêm hoặc xóa thành viên vào vòng tròn gia đình.
- Rate limiting cho API xác thực và API SOS; khóa tạm thời khi vượt giới hạn (chống brute-force và spam).

### 3.3. Quyền riêng tư và kiểm toán

- Consent có thể thu hồi: thành viên tự tắt chia sẻ vị trí bất kỳ lúc nào, thiết bị khác mất quyền đọc ngay.
- Nhật ký minh bạch (transparency log): ghi lại ai xem vị trí của ai, vào lúc nào — hiển thị cho người dùng.
- Phân quyền theo vai trò và theo quan hệ trong vòng tròn (RBAC + quan hệ).
- Tự động xóa dữ liệu vị trí cũ theo chính sách thời gian (data minimization).

### 3.4. Bảo vệ thiết bị và kênh truyền

- HTTPS kết hợp certificate pinning cho mọi kết nối tới máy chủ.
- Mã hóa cơ sở dữ liệu cục bộ bằng SQLCipher, khóa nằm trong Keystore.
- FLAG_SECURE chặn chụp màn hình trên các màn hình nhạy cảm; tự khóa ứng dụng khi rời nền.
- Mã chia sẻ hành trình dùng một lần, có thời hạn ngắn, chống chụp lại và chống replay.
- Làm rối mã nguồn bằng R8/ProGuard; phát hiện trạng thái root / Developer Options và cảnh báo.

---

## 4. KIẾN TRÚC HỆ THỐNG VÀ CÔNG NGHỆ SỬ DỤNG

### 4.1. Kiến trúc tổng thể

Kiến trúc 3 tầng: **Client (Android) — Backend trung gian (relay + xác thực + push) — Cơ sở dữ liệu và dịch vụ bên thứ ba.**

Ranh giới tin cậy được đặt tại máy chủ: mọi thứ đi qua máy chủ đều ở dạng ciphertext, trừ dữ liệu tài khoản và metadata không nhạy cảm (thành viên, quyền, trạng thái đồng bộ).

### 4.2. Công nghệ

| Hạng mục | Công nghệ |
|---|---|
| Ngôn ngữ / nền tảng | Kotlin (Android) — hoặc Flutter nếu nhóm ưu tiên tốc độ phát triển |
| Backend | Firebase (Firestore, Realtime Database, Cloud Functions, FCM) hoặc Node.js + Express |
| Xác thực | Firebase Authentication (email + OTP) |
| Mật mã | libsodium / thư viện JCA cho X25519 và AES-GCM; Android Keystore để lưu khóa |
| CSDL cục bộ | Room + SQLCipher |
| Bản đồ | Google Maps SDK / OpenStreetMap |
| Push | Firebase Cloud Messaging |
| Làm rối mã | R8/ProGuard khi build release |

---

## 5. MÔ HÌNH DỮ LIỆU VÀ GIAO THỨC TRUYỀN THÔNG

### 5.1. Các thực thể chính

| Thực thể | Mô tả |
|---|---|
| `User` | Tài khoản, mật khẩu đã băm, khóa công khai X25519, số điện thoại đã xác minh |
| `FamilyCircle` | Vòng tròn gia đình, danh sách thành viên, quyền chia sẻ vị trí |
| `LocationPing` | Vị trí đã mã hóa, thời điểm, nonce, TTL |
| `SOSEvent` | Cảnh báo SOS: vị trí mã hóa, tham chiếu bản ghi âm, trạng thái đã xem |
| `ShareCode` | Mã chia sẻ hành trình: mã 6 chữ số băm, hạn dùng, số lần dùng |
| `AuditLog` | Bản ghi ai xem vị trí của ai, vào lúc nào |

### 5.2. Luồng đăng nhập và thiết lập vòng tròn

1. Người dùng đăng ký bằng email/OTP; máy sinh cặp khóa X25519, private key lưu trong Keystore, public key gửi lên server.
2. Máy chủ xác thực bằng JWT, trả về access token và refresh token.
3. Người dùng nhập mã OTP của người thân để thêm vào vòng tròn; thành viên mới nhận public key của thành viên cũ.
4. Hai bên thống nhất shared secret qua X25519; từ đó mọi payload dùng AES-256-GCM với nonce ngẫu nhiên.

### 5.3. Luồng gửi SOS (trọng tâm demo)

1. Người dùng nhấn nút SOS; ứng dụng mã hóa payload gồm vị trí, thời điểm và khóa bản ghi âm.
2. Bản ghi âm ngắn được mã hóa và tải lên; máy chủ lưu dưới dạng blob không đọc được.
3. Máy chủ gửi thông báo FCM; thiết bị thành viên nhận được, tải ciphertext về và giải mã bằng khóa riêng.
4. Hiển thị vị trí và phát bản ghi âm; ghi vào nhật ký ai đã xem.

### 5.4. Điểm demo then chốt

Mở Firestore / bảng dữ liệu trên máy chủ và hiển thị payload vị trí — **toàn bộ là chuỗi ciphertext không đọc được**. Đây là ảnh chụp màn hình quan trọng nhất trong buổi bảo vệ đồ án.

---

## 6. KHUNG BÁO CÁO VÀ KẾ HOẠCH THỰC HIỆN

Báo cáo bám theo khung của các báo cáo mẫu trong thư mục tài liệu tham khảo.

### 6.1. Khung báo cáo

- **Mở đầu:** bối cảnh, lý do chọn đề tài, mục tiêu, đối tượng và phạm vi.
- **Chương 1 — Cơ sở lý thuyết:** tổng quan an toàn và bảo mật; mô hình bảo mật; các nguyên lý mã hóa (X25519, AES-GCM, băm, chữ ký số); cơ chế bảo mật thường dùng trên thiết bị di động; cơ sở chọn đề tài.
- **Chương 2 — Phân tích và thiết kế hệ thống:** phân tích yêu cầu, thiết kế chức năng, thiết kế kiến trúc, mô hình dữ liệu, luồng xử lý, mô hình bảo mật và phân tích đe dọa (threat model).
- **Chương 3 — Kết quả thực nghiệm:** giao diện và chức năng đã triển khai, kết quả kiểm thử từng cơ chế bảo mật, đánh giá hiệu năng và độ trễ, ảnh chụp màn hình chứng minh E2EE.
- **Chương 4 — Kết luận và hướng phát triển.**
- **Tài liệu tham khảo.**

### 6.2. Kế hoạch thực hiện

| Tuần | Công việc |
|---|---|
| Tuần 1 | Khởi tạo dự án, xác thực Firebase, cơ sở dữ liệu, màn hình vòng tròn gia đình và bản đồ vị trí realtime (chưa mã hóa) |
| Tuần 2 | Nút SOS (cảnh báo + bản ghi âm), mã hóa E2EE, quản lý khóa trong Keystore |
| Tuần 3 | Consent thu hồi được, nhật ký minh bạch, mã chia sẻ hành trình, geofence, FLAG_SECURE, R8 |
| Tuần 4 | Kiểm thử từng cơ chế bảo mật, chụp ảnh màn hình demo, viết báo cáo và slide bảo vệ |

---

## 7. KẾT QUẢ KỲ VỌNG VÀ TIÊU CHÍ ĐÁNH GIÁ

### 7.1. Kết quả kỳ vọng

- Ứng dụng chạy ổn định trên 2 thiết bị Android thật, demo hai chiều vị trí và SOS.
- Mã hóa đầu cuối được chứng minh bằng dữ liệu thực trên máy chủ.
- Có tối thiểu 8 cơ chế bảo mật được mô tả, phân tích, triển khai và kiểm thử.
- Báo cáo đầy đủ 4 chương theo khung mẫu, có ảnh chụp màn hình chứng minh.

### 7.2. Tiêu chí đánh giá

| Tiêu chí | Nội dung |
|---|---|
| Tính đúng đắn | Ứng dụng đáp ứng đúng các chức năng đã đăng ký, không lỗi chặn luồng chính |
| Tính bảo mật | Mỗi cơ chế có threat model, được kiểm thử bằng cách tấn công thực tế và ghi kết quả |
| Tính khả thi | Đồ án nộp đúng hạn, demo được trên thiết bị thật, không phụ thuộc môi trường riêng |
| Chất lượng báo cáo | Cấu trúc chặt chẽ, phân tích sâu, tham khảo đúng, trích dẫn hợp lệ |

---

*— Hết đề cương —*
