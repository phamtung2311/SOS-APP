# SLIDE THUYẾT TRÌNH BẢO VỆ ĐỒ ÁN — ATBM

## ỨNG dụng SOS & An toàn Gia đình — Mã hóa đầu cuối trên thiết bị di động

**Kịch bản thuyết trình: 12–15 phút, 17 slide.**
*Chuẩn bị: mở sẵn ứng dụng trên 2 máy ảnh, mở sẵn Firestore console, mở sẵn Crypto Inspector.*

---

### SLIDE 1 — Trang bìa

**ỨNG DỤNG SOS & AN TOÀN GIA ĐÌNH**
*Theo dõi vị trí và cầu cứu khẩn cấp mã hóa đầu cuối trên thiết bị di động*

- Môn: **An toàn & Bảo mật trong Phát triển Ứng dụng Di động (ATBM)**
- Học viện Kỹ thuật Mật mã — Khoa CNTT
- Người hướng dẫn: **Thái Thị Thanh Vân**
- Lớp: L03 · Năm 2025

> *Mở đầu: "Xin chào thầy cô và các bạn. Em xin trình bày đồ án ứng dụng SOS & An toàn Gia đình — một ứng dụng theo dõi vị trí và cầu cứu khẩn cấp, trong đó toàn bộ dữ liệu vị trí được mã hóa đầu cuối, máy chủ không thể đọc."*

---

### SLIDE 2 — Vấn đề thực tiễn

**TẠI SAO CẦN MỘT ỨNG DỤNG SOS AN TOÀN?**

- Trẻ em, người cao tuổi, người làm nghề nguy hiểm — nhóm có nguy cơ **bắt cóc, tai nạn, lạc đường** cao nhất
- Vài phút chậm trễ cứu người quyết định sự sống → ứng dụng phải **cứu được**
- Nhưng dữ liệu vị trí là dữ liệu **nhạy cảm nhất** → ứng dụng phải **bảo vệ được**

**Vấn đề của các ứng dụng hiện nay:**

| Vấn đề | Hậu quả |
|---|---|
| Dữ liệu vị trí gửi lên server dạng **plaintext** | Server đọc được mọi vị trí |
| Server nắm giữ khóa | Một điểm hỏng = toàn bộ rò rỉ |
| Nguy cơ bán dữ liệu vị trí từ nhà mạng / bên thứ ba | Suy ra nơi ở, nơi làm việc, thói quen sinh hoạt |

> *"Hai yêu cầu này có vẻ mâu thuẫn. Kiến trúc Emergency Bypass của em giải quyết trực tiếp mâu thuẫn đó."*

---

### SLIDE 3 — Đề tài & điểm khác biệt

**ĐỀ TÀI: ỨNG DỤNG SOS & AN TOÀN GIA ĐÌNH**

**Điểm khác biệt cốt lõi:** toàn bộ dữ liệu vị trí và nội dung cảnh báo được **mã hóa đầu cuối (E2EE)** — máy chủ chỉ chuyển tiếp mã ciphertext, **không thể đọc nội dung**.

**3 điểm ăn tiền của đồ án:**

1. 🔐 **E2EE thực sự** — X25519 + AES-256-GCM, chứng minh bằng dữ liệu thật trên Firestore
2. 🚨 **Kiến trúc Emergency Bypass** — cứu hộ khẩn cấp không có rào cản nào
3. ⚡ **Hiệu năng mật mã < 1 ms** — bảo mật không phải đánh đổi bằng trải nghiệm

---

### SLIDE 4 — Mục tiêu & phạm vi

**MỤC TIÊU**

- Ứng dụng Android hoàn chỉnh: theo dõi realtime, SOS, geofence, chia sẻ hành trình, chat E2EE, nhật ký
- **Bí mật** của dữ liệu vị trí — server không đọc được
- **Quyền kiểm soát** của người dùng — consent thu hồi được, nhật ký minh bạch
- **Đánh giá bằng thực nghiệm** — mỗi cơ chế bảo mật phải bị tấn công thật

**PHẠM VI**

| Trong phạm vi | Ngoài phạm vi |
|---|---|
| Android (minSdk 10) | iOS, Web |
| Bản đồ online (OSM) | Bản đồ offline |
| Geofence hình tròn (Euclid) | Geofence đa giác |
| Sinh trắc học native (Face ID/Touch ID) | Tự viết liveness detection |
| APK cài trực tiếp | Triển khai App Store |

---

### SLIDE 5 — 8 cơ chế bảo mật

**TÁM CƠ CHẾ BẢO MẬT — MỖI CƠ CHẾ ĐỀU CÓ THREAT MODEL RIÊNG**

| # | Cơ chế | Chống được gì |
|---|---|---|
| 1 | ECDH X25519 + HKDF-SHA256 | Nghe lén, MITM ở tầng thỏa thuận khóa |
| 2 | AES-256-GCM (E2EE) | Nghe lén, can thiệp dữ liệu |
| 3 | Nonce ngẫu nhiên 96-bit | Tái sử dụng nonce phá vỡ GCM |
| 4 | Anti-replay (Nonce Registry) | Tấn công phát lại |
| 5 | Mock GPS detection | Giả mạo vị trí |
| 6 | Root detection + `FLAG_SECURE` | Thiết bị đã root, chụp màn hình |
| 7 | Scoped Biometrics | Truy cập dữ liệu nhạy cảm |
| 8 | CSPRNG + SHA-256 + TTL | Đoán mã chia sẻ, dùng lại mã cũ |

> *"Em không chỉ mô tả — em đã viết test tấn công thật vào từng cơ chế này."*

---

### SLIDE 6 — Chương 1: Nguyên lý mật mã

**NỀN TẢNG MẬT MÃ — 4 THUẬT TOÁN, 4 LÝ DO CHỌN**

| Thuật toán | Tham số | Vì sao chọn |
|---|---|---|
| **X25519** (ECDH) | khóa 32 byte cố định | Loại bỏ nhóm tham số yếu, nhanh trên CPU di động |
| **HKDF-SHA256** | RFC 5869 | Rút khóa 32 byte đều từ shared secret, tách khóa theo `info` |
| **AES-256-GCM** | nonce 12B, tag 16B | AEAD — giải mã **tự kiểm tra** MAC, 1 thao tác loại 2 lớp lỗi |
| **SHA-256 + CSPRNG** | `Random.secure()` | Mã 6 số từ RNG phần cứng, lưu trữ dạng băm |

**Điểm yếu còn lại của X25519:** nó **không tự xác thực** — không chứng minh danh tính đối phương. → Hướng phát triển: chữ ký Ed25519.

---

### SLIDE 7 — Chi tiết đắt giá: Empty Salt trên Android JCE

**MỘT CHI TIẾT TRIỂN KHAI ĐÁNG GHI NHẬN**

Theo RFC 5869, HKDF chấp nhận `salt` rỗng. Nhưng trên **Android JCE**, salt được truyền vào HMAC như một *khóa* → salt rỗng ⇒ `InvalidKeyException: Empty key`.

→ Dùng **salt 32 byte toàn 0x00**: *đúng bằng* salt rỗng theo RFC, nhưng tránh được lỗi JCE.

```dart
_hkdf.deriveKey(
  secretKey: sharedSecret,
  nonce: Uint8List(32),   // salt 32 byte 0 — tương đương RFC 5869
  info: utf8.encode('sos_safe_family_aes_key'),
);
```

> *"Hiểu đúng mật mã chưa đủ — phải hiểu đúng cả hệ sinh thái triển khai của nền tảng đích."*

---

### SLIDE 8 — Chương 2: Kiến trúc 3 tầng

**KIẾN TRÚC & RANH GIỚI TIN CẬY**

```
┌─────────────────────── CLIENT (Android) ───────────────────────┐
│  8 màn hình  →  AppState (ChangeNotifier)  →  Data Layer        │
│                    CryptoService: X25519 · HKDF · AES-GCM        │
│  MainActivity.kt: FLAG_SECURE · Root check    Keystore          │
└────────────────────────────┬─────────────────────────────────────┘
                             │  CHỈ ciphertext + metadata
┌────────────────────────────▼─────────────────────────────────────┐
│  SERVER (Firestore + Auth + FCM) — ROLE: RELAY                    │
│  Không giải mã. Không giữ khóa phiên.                             │
└──────────────────────────────────────────────────────────────────┘
```

**Ranh giới tin cậy đặt tại máy chủ** → biến server từ *"bên tin cậy"* thành *"kênh truyền tin"*, loại bỏ toàn bộ lớp tấn công "server lộ dữ liệu".

---

### SLIDE 9 — Kiến trúc Emergency Bypass ⭐

**TRIẾT LÝ THIẾT KẾ SỐNG CÒN**

Thiết kế truyền thống: `đăng nhập → sinh trắc học → mới hiện nút SOS`
→ Người bị tấn công không gõ được mật khẩu → **không gửi được cảnh báo**. Rào cản bảo mật đã trở thành rủi ro.

| Nguyên tắc | Áp dụng |
|---|---|
| **Zero Barrier** | Mở app → vào thẳng Map + nút SOS. Không đăng nhập, không sinh trắc học chặn đường vào. |
| **Scoped Gate** | Sinh trắc học chỉ bảo vệ **vùng dữ liệu nhạy cảm**: Vòng tròn, Chat E2EE, Nhật ký, Cài đặt bảo mật. |

**Kết quả:** gửi SOS trong **≤ 2 giây** (nhấn giữ 2s), nhưng dữ liệu nhạy cảm vẫn được bảo vệ.

> *"Bảo mật không được phép trở thành lý do khiến nạn nhân không được cứu."*

---

### SLIDE 10 — Threat Model (STRIDE)

**PHÂN TÍCH ĐE DỌA THEO STRIDE**

| | S | T | R | I | D | E |
|---|---|---|---|---|---|---|
| **Truyền vị trí** | E2EE | GCM tag | ReplayGuard | AEAD | — | Consent thu hồi |
| **Nút SOS** | Payload mã hóa | MAC + replay | TTL 30′ | Nonce | — | Zero Barrier |
| **Mã chia sẻ** | SHA-256 + TTL | — | Hạn ngắn | CSPRNG | — | Thu hồi mã |
| **Thiết bị** | — | — | — | `isMocked` | `FLAG_SECURE` | Root check |

**Đe doạ hệ thống KHÔNG giải quyết được** *(nêu trung thực)*:
- X25519 không tự xác thực → MITM lúc thỏa thuận khóa vẫn khả dĩ
- `ReplayGuard` lưu trong RAM → thiết bị đã root có thể xoá bộ nhớ
- Mã 6 số vẫn dò được nếu không rate-limit ở server

---

### SLIDE 11 — Giao thức E2EE & chống phát lại

**GIAO THỨC TRAO ĐỔI KHÓA & MÃ HÓA HAI CHIỀU**

```
Alice                                   Server (relay)                Bob
   │ sinh cặp khóa X25519                   │                          │
   │ private key → Keystore                 │◄──── publicKey_Bob ──────┤
   │ ECDH(priv_A, pub_B) = sharedSecret    │                          │
   │ HKDF-SHA256 → sessionKey 32B          │                          │
   │        (Server KHÔNG thấy sessionKey)  │                          │
```

**Định dạng vận chuyển chuẩn:** `nonce (12B) ‖ mac (16B) ‖ ciphertext`

**Luồng nhận SOS — 3 lớp kiểm tra (đúng thứ tự chi phí):**
1. **Nonce Registry** — nonce trùng? → `duplicateNonce`, **không giải mã** (chặn spam + bảo vệ CPU)
2. **Giải mã AES-GCM** — MAC sai? → `SecretBoxAuthenticationError`
3. **Timestamp đã xác thực** — quá 30 phút? → `expired`

→ Mọi hành vi tấn công đều được ghi vào **nhật ký kiểm toán minh bạch**.

---

### SLIDE 12 — Chương 3: Benchmark hiệu năng ⭐

**SỐ LIỆU THỰC NGHIỆM — 300 VÒNG LẶP MỖI THAO TÁC**

| Thao tác | Trung bình | Thông lượng | Ngưỡng | KQ |
|---|---|---|---|---|
| ECDH X25519 (thỏa thuận khóa) | **0,80 ms** | 1.353 ops/s | < 10 ms | ✅ |
| AES-256-GCM **Encrypt** (vị trí SOS) | **0,11 ms** | 10.077 ops/s | < 10 ms | ✅ |
| AES-256-GCM **Decrypt** (vị trí SOS) | **0,08 ms** | 13.944 ops/s | < 10 ms | ✅ |
| SHA-256 (mã chia sẻ 6 số) | **0,03 ms** | 39.793 ops/s | < 10 ms | ✅ |
| E2EE Chat Decrypt | **0,05 ms** | 21.008 ops/s | < 10 ms | ✅ |

**Phân tích:**
- ECDH chậm nhất (~7× AES) vì đường cong elliptic đắt — **nhưng chỉ chạy 1 lần** khi lập phiên
- Mã hóa vị trí **< 0,1 ms** = **< 0,1%** chu kỳ cập nhật 10 giây → **hoàn toàn trong suốt** với người dùng (< 50 ms)
- Kết luận: **bảo mật không phải đánh đổi bằng trải nghiệm**

---

### SLIDE 13 — Kết quả 4 kịch bản tấn công ⭐

**SECURITY ATTACK TEST SUITE — 23 TEST TẤN CÔNG, TẤT CẢ ĐỀU BỊ CHẶN**

| Kịch bản | Cách tấn công | Kết quả |
|---|---|---|
| 🔍 **Nghe lén** (MITM) | Bắt gói tin SOS & chat trên đường truyền | Ciphertext **không chứa** tọa độ hay plaintext — rò rỉ **0 byte**; bên thứ ba không private key **không giải mã được** |
| 🔧 **Can thiệp** (Bit-flip) | Đảo **1 bit** ciphertext / MAC / nonce | Lập tức ném `SecretBoxAuthenticationError` — **tính toàn vẹn được bảo toàn** |
| 🔁 **Phát lại** (Replay) | Ghi lại gói tin cũ rồi gửi lại | `ReplayGuard` chặn: **trùng nonce** hoặc **quá hạn 30′** → từ chối + ghi log |
| 📍 **Giả GPS** | `Position(isMocked: true)` | `isTrusted = false`, `isMockGps = true`, hiển thị cảnh báo **"Phát hiện GPS giả lập"** |

> *"Đây không phải mô phỏng — đây là tấn công thật vào code thật, buộc từng cơ chế phải thất bại trước kẻ tấn công."*

---

### SLIDE 14 — Điểm ăn tiền: phát hiện lỗ hổng của chính đồ án

**BÀI HỌC LỚN NHẤT CỦA ĐỒ ÁN**

Khi viết test tấn công ở Milestone 6, em phát hiện ra đồ án của em **thiếu hoàn toàn cơ chế chống phát lại** — trong khi đề cương mục 3.4 yêu cầu "chống chụp lại và chống replay".

| | |
|---|---|
| Trước M6 | Cảm giác "đã an toàn" vì đã dùng AES-GCM — nhưng **chưa tấn công nào chạm vào nó** |
| M6 | Viết test tấn công → **phát hiện khoảng trống replay** |
| M7 | Xây dựng `ReplayGuard` (Nonce Registry) + `handleIncomingSos()` + tích hợp vào `AppState`, ghi cảnh báo vào nhật ký kiểm toán |

> *"Bảo mật không phải trạng thái đạt được một lần — nó là thuộc tính phải duy trì liên tục."*

---

### SLIDE 15 — Kiểm thử & chất lượng mã

**96/96 TEST PASS — 0 ERROR, 0 WARNING, 0 INFO**

| File test | Số test | Nội dung |
|---|---|---|
| `geofence_test.dart` | 23 | Haversine, so sánh `latlong2`, vào/ra vùng |
| `security_attack_suite_test.dart` | 18 | **4 kịch bản tấn công** + tích hợp ReplayGuard |
| `sos_test.dart` | 22 | Đóng gói, ACTIVE→RESOLVED, AES-GCM, **5 test `handleIncomingSos`** |
| `chat_e2ee_test.dart` | 9 | Round-trip E2EE, rò plaintext, mã hóa media |
| `trip_share_test.dart` | 7 | CSPRNG, SHA-256, TTL |
| `widget_test.dart` | 6 | Nav, nhấn giữ SOS, đếm ngược 3-2-1, banner |
| `emergency_bypass_test.dart` | 5 | Zero Barrier, scoped gate, FLAG_SECURE |
| `crypto_service_test.dart` | 4 | ECDH 2 chiều, tamper, ngẫu nhiên nonce |
| `crypto_benchmark_test.dart` | 2 | Benchmark + assert < 10 ms |

**Quy mô:** 5.061 dòng Dart (`lib/`) · 1.970 dòng test · 100 dòng Kotlin native
**Chạy headless trong ~2 giây** — không cần thiết bị thật để kiểm thử bảo mật.

---

### SLIDE 16 — Đối chiếu đề cương & hướng phát triển

**ĐÁNH GIÁ SO VỚI ĐỀ CƯƠNG**

| Tiêu chí | Kết quả | Đạt |
|---|---|---|
| Tính đúng đắn | 96/96 test PASS, 0 lỗi phân tích | ✅ |
| Tính bảo mật | 8/8 cơ chế có threat model + tấn công thực tế | ✅ |
| Chất lượng báo cáo | Đúng khung mục 6.1, 14 tài liệu tham khảo | ✅ |
| Tính khả thi | Chưa demo 2 thiết bị thật (chưa có thiết bị) | ⚠️ |

**HƯỚNG PHÁT TRIỂN**

| Ưu tiên | Hạng mục |
|---|---|
| 🔴 Cao | Tích hợp Firestore listener thật · Chữ ký Ed25519 (chặn MITM) · Demo 2 thiết bị thật + ảnh E2EE |
| 🟡 TB | **Mesh ngoại tuyến (BLE / Wi-Fi Direct)** khi mất mạng · Mã hóa bản ghi âm E2EE · Rate limiting · SQLCipher · Certificate pinning |
| 🟢 Thấp | Geofence đa giác · Mã chia sẻ dạng từ ngữ |

---

### SLIDE 17 — Kết luận

**KẾT LUẬN**

> *"Đồ án này xây dựng được một ứng dụng với mô hình bảo mật **'máy chủ không đọc được nội dung'** — vững hơn nhiều so với mức 'đăng nhập + băm mật khẩu' phổ biến.*
>
> *Giá trị lớn nhất không nằm ở danh sách tính năng, mà ở việc **chứng minh được bằng thực nghiệm**: 23 test tấn công thực sự bắn vào từng cơ chế bảo mật; một lỗ hổng replay bị phát hiện bằng chính phương pháp đó đã được vá; và mọi thao tác mật mã đều nhanh hơn 1 ms — nghĩa là **bảo mật trong đồ án này không phải đánh đổi bằng trải nghiệm**."*

**Cảm ơn thầy cô và các bạn!**
*Hứa hẹn nhận được câu hỏi.*

---

## PHỤ LỤC — GỢI Ý XỬ LÝ CÂU HỎI HỘI ĐỒNG

| Câu hỏi dự kiến | Trả lời ngắn |
|---|---|
| *Server có đọc được vị trí không?* | Không. Server chỉ giữ ciphertext; `sessionKey` chỉ tồn tại ở 2 thiết bị. Có thể mở Firestore console demo. |
| *Không có mạng thì sao?* | Đây là hạn chế đã nêu — hướng M8 là Mesh BLE/Wi-Fi Direct để truyền cảnh báo ngoại tuyến. |
| *Chữ ký khóa đâu?* | X25519 không tự xác thực → chữ ký Ed25519 là hạng mục ưu tiên cao của M8. Đã nêu rõ trong báo cáo. |
| *Có chống được hacker không?* | Không giải quyết được 100%. Đồ án nêu rõ 4 đe doạ chưa giải quyết được (mục 2.3). |
| *Số liệu benchmark có chính xác không?* | Đo trên `flutter test` headless, 300 vòng, có warm-up; đã in bảng ra console, tái lập được. |
| *Vì sao không dùng RSA/ECDSA?* | X25519 nhanh hơn, khóa cố định 32 byte, loại bỏ nhóm tham số yếu — phù hợp di động. |
