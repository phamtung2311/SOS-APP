# KẾ HOẠCH LẬP TRÌNH DÀI HẠN — ỨNG DỤNG SOS & AN TOÀN GIA ĐÌNH

> Dùng cùng đề cương `De_cuong_SOS_An_toan_Gia_dinh.md`. Kế hoạch này chi tiết hoá **phần lập trình**, chia thành các mốc (milestone) với tiêu chí nghiệm thu rõ ràng.

---

## 0. TRIẾT LÝ VÀ NGUYÊN TẮC LÀM VIỆC

### 0.1. Nguyên tắc cốt lõi

1. **Demo được từ ngày đầu.** Không xây "nền tảng" rồi mới có tính năng. Mỗi tuần phải có ứng dụng chạy được trên 2 máy thật.
2. **Bảo mật là hạng mục, không phải lớp trang trí.** Mỗi cơ chế bảo mật phải có **script kiểm thử tấn công** đi kèm, không chỉ "đã cài đặt".
3. **E2EE là đường đi chính (main path), không phải lớp bọc.** Nếu tồn tại đường đi không mã hóa thì đó là lỗ hổng, không phải tính năng.
4. **Ưu tiên giảm phạm vi hơn tăng chất lượng code.** Đồ án hoàn thành 80% với bug = 0 thắng đồ án 100% có bug.

### 0.2. Quy tắc vibe code (quan trọng — đọc kỹ)

| Nên | Không nên |
|-----|-----------|
| Viết prompt cụ thể, có ràng buộc kỹ thuật rõ ràng | Prompt mơ hồ kiểu "làm app giống app X" |
| Mỗi module một task, build xong mới sang task sau | Viết 10 màn hình trong 1 prompt rồi debug từ đầu |
| Yêu cầu AI viết **test** kèm theo | Nhận code xong không chạy `flutter analyze` |
| Sau mỗi thay đổi: `flutter analyze` + `flutter test` | Sửa 5 file rồi mới chạy build lần đầu |
| Chủ động commit (WIP) sau mỗi tính năng nhỏ | Code 5000 dòng rồi mới commit lần đần |
| Đọc lại code AI sinh ra trước khi merge | Tin tuyệt đối vào code AI, đặc biệt phần crypto |

### 0.3. Quy tắc đặc biệt cho phần mật mã (bắt buộc)

> ⚠️ **Không tự viết thuật toán mã hóa.** Chỉ dùng thư viện đã kiểm định.

- ❌ Không tự viết AES, Diffie-Hellman, RSA, băm.
- ✅ Dùng `cryptography` (package Dart, bọc `cryptography_flutter` → libsodium) hoặc `pointycastle`.
- ✅ X25519 cụ thể: `cryptography` package hỗ trợ `X25519`.
- ✅ AES-GCM: `AesGcm.with256bits()`.
- ✅ Băm mật khẩu: `cryptography` hỗ trợ Argon2id; hoặc Firebase Auth xử lý sẵn (server-side).
- ⚠️ **Luôn** dùng nonce ngẫu nhiên 96-bit cho AES-GCM, không tái sử dụng.
- ⚠️ **Luôn** dùng constant-time compare khi so khóa/signature.
- ✅ Bảo vệ private key: **không** lưu private key dạng plaintext trong SharedPreferences hay file thường.

**Bảo mật khóa trên Android (quan trọng):**

| Cơ chế | Dùng cho | Ghi chú |
|---|---|---|
| `flutter_secure_storage` (EncryptedSharedPreferences) | Token, khoá đã mã hoá | Dễ, đa nền tảng |
| `Android Keystore` + RSA keypair (via `MethodChannel`/plugin) | Bọc khóa phiên E2EE | Khóa private **không bao giờ** rời TEE |
| `libflutter_secure_storage` với `AndroidOptions(encryptedSharedPreferences: true)` | Mặc định nên dùng | Keystore-backed AES key |

**Chiến lược thực tế (không quá phức tạp):**
- Sinh cặp X25519 ngẫu nhiên trong app bằng `cryptography`.
- **Private key → lưu vào `flutter_secure_storage`** (mã hóa bằng khóa trong Android Keystore).
- Public key → upload server.
- Khi cần mã hóa cho nhóm: sinh ephemeral X25519 → ECDH → shared secret → HKDF → AES-256-GCM key.
- *Ghi chú giáo viên:* nếu thời gian cho phép, nâng lên Keystore-wrapped RSA ở chương 3 và so sánh.

### 0.4. Quy trình commit

```
git commit -m "feat(circle): tạo vòng tròn gia đình + thêm thành viên" 
```
- Nhánh: `main` luôn chạy được; feature branch cho từng nhánh chức năng lớn.
- Tag mỗi milestone: `v0.1-auth`, `v0.2-map`, `v0.3-sos`, `v0.4-e2ee`...
- **Luôn** kèm `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` nếu commit do AI sinh.

---

## 1. BỐI CẢNH & CÔNG CỤ

### 1.1. Môi trường hiện có

| Thành phần | Trạng thái |
|---|---|
| Hệ điều hành | Fedora Linux 44 (Workstation) |
| Java | OpenJDK 25.0.4.1 ✅ |
| Node.js | v22.23.1 ✅ (cho Cloud Functions) |
| Android SDK | ✅ tại `~/Android/Sdk` (có emulator, platform-tools, build-tools) |
| ADB | 1.0.41 ✅ |
| `~/.gradle` | có sẵn cache ✅ |
| RAM | 15GB, 20 nhân CPU ✅ |
| Disk trống | 222GB ✅ |

**Cần cài thêm:** Flutter SDK → `~/dev/flutter` (đang tải).

### 1.2. Ngăn ngừa lỗi "500MB mà không biết lỗi ở đâu"

Flutter lần đầu build Gradle rất lâu. Giải pháp: **dựng project mẫu ngay tuần 0** để tải sẵn Gradle dependencies, biết chắc toolchain hoạt động trước khi viết tính năng.

### 1.3. Stack quyết định

| Tầng | Chọn | Lý do |
|---|---|---|
| App | **Flutter** (Kotlin) | Vibe code nhanh nhất, 1 codebase, `cryptography` package hỗ trợ tốt, cộng đồng lớn |
| State | Riverpod | Đơn giản hơn Bloc, đủ cho app này |
| Backend | **Firebase** (Firestore + Auth + FCM + Cloud Functions) | Không cần viết & deploy server → tiết kiệm 1–2 tuần |
| Crypto | `cryptography` + `cryptography_flutter` | X25519, AES-GCM, HKDF chuẩn |
| Storage | `flutter_secure_storage` + `sqflite_sqlcipher` | Token/khoá an toàn + CSDL mã hoá |
| Map | `flutter_map` (OSM) hoặc `google_maps_flutter` | `flutter_map` miễn phí, không cần API key → **chọn flutter_map** |
| Location | `geolocator` + `background_locator_2` | GPS + cập nhật nền |
| Push | `firebase_messaging` | FCM |
| Test | `flutter_test`, `integration_test`, `flutter_secure_storage` mock | Unit + widget test |

> **Lưu ý Google Maps:** cần API key và billing account → tránh rủi ro giữa đường. `flutter_map` dùng tile OSM miễn phí, cũng là lựa chọn hợp lý về mặt đạo đức (ghi rõ attribution trong báo cáo).

---

## 2. LỘ TRÌNH TỔNG THỂ (6 TUẦN + BUFFER)

```
Tuần 0  │ Toolchain + Project skeleton + CI lint + test xanh        ← NỀN TẢNG
Tuần 1  │ Auth + Firestore + vòng tròn gia đình (CRUD)              ← M1
Tuần 2  │ Bản đồ + vị trí realtime + geofence cơ bản               ← M2
Tuần 3  │ SOS: nút + push + ghi âm + audit log                      ← M3
Tuần 4  │ E2EE: X25519 + AES-GCM + consent + nhật ký minh bạch      ← M4  ★ ĐỘT NHẤN
Tuần 5  │ Chia sẻ hành trình + hardening (FLAG_SECURE, R8, pinning) │ M5
Tuần 6  │ Kiểm thử tấn công + tối ưu + viết báo cáo                ← M6
Buffer  │ Dự phòng: emulator bị lỗi, Firebase quota, thiết bị hỏng │
```

> **Nguyên tắc ghép:** Mỗi milestone kết thúc = **1 tag git + 1 video demo 60 giây + cập nhật đề cương**. Nếu trượt milestone → cắt tính năng (theo thứ tự ưu tiên cắt ở mục 8), **không** cắt phần bảo mật.

---

## 3. MILESTONE 0 — TOOLCHAIN & SKELETON (Tuần 0)

**Mục tiêu:** tạo được app chạy được trên emulator, đã "nóng" Gradle cache, pipeline lint+test xanh.

| # | Việc | Cách làm |
|---|------|----------|
| 0.1 | Cài Flutter SDK | `tar xf` vào `~/dev/flutter`, thêm vào `~/.bashrc`: `export PATH="$HOME/dev/flutter/bin:$PATH"` |
| 0.2 | `flutter doctor` | Chấp nhận cảnh báo Android licenses; `flutter doctor --android-licenses` |
| 0.3 | Tạo project | `flutter create --org vn.atbm.sos --platforms=android sos_safe_family` |
| 0.4 | Cấu trúc thư mục | Theo mục 4 |
| 0.5 | Dependency cốt lõi | `flutter pub add` theo bảng mục 1.3 |
| 0.6 | **Warm-up build** | `flutter build apk --debug` — tải sẵn toàn bộ Gradle deps (lần đầu 10–20 phút) |
| 0.7 | CI lint + test | Script `tool/ci.sh`: `flutter analyze && flutter test` |
| 0.8 | Git init + commit | Commit "chore: khởi tạo project" |
| 0.9 | Tạo project Firebase | Console: bật Auth (email+OTP), Firestore, FCM; tải `google-services.json` |

**Tiêu chí nghiệm thu:** `flutter build apk --debug` thành công, app hiện màn hình trắng trên emulator, `flutter analyze` không có lỗi, `flutter test` xanh.

**⚠️ Vài mẹo:** lần đầu `flutter build apk` rất lâu → chạy 1 lần sớm. Nếu Gradle lỗi phiên bản Java → đặt `JAVA_HOME` đúng JDK 17/21. Nếu thiếu license Android → `yes | flutter doctor --android-licenses`.

---

## 4. CẤU TRÚC THƯ MỤC & KIẾN TRÚC CODE

```
sos_safe_family/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── theme.dart
│   │   ├── constants.dart
│   │   └── result.dart              # sealed class Result<T> cho error handling
│   ├── data/
│   │   ├── models/
│   │   │   ├── user.dart
│   │   │   ├── family_circle.dart
│   │   │   ├── location_ping.dart
│   │   │   ├── sos_event.dart
│   │   │   ├── share_code.dart
│   │   │   └── audit_log.dart
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart
│   │   │   ├── circle_repository.dart
│   │   │   ├── location_repository.dart
│   │   │   ├── sos_repository.dart
│   │   │   └── audit_repository.dart
│   │   └── services/
│   │       ├── key_service.dart      # ★ sinh/lưu/load khóa, E2EE
│   │       ├── crypto_service.dart   # ★ X25519, AES-GCM, HKDF
│   │       ├── secure_storage.dart   # wrapper flutter_secure_storage
│   │       ├── location_service.dart # GPS + background
│   │       ├── push_service.dart     # FCM
│   │       └── tamper_detector.dart  # root/debug check
│   ├── features/
│   │   ├── auth/  { data, presentation }
│   │   ├── circle/ { data, presentation }
│   │   ├── map/  { data, presentation }
│   │   ├── sos/  { data, presentation }
│   │   ├── share/ { data, presentation }
│   │   └── audit/ { data, presentation }
│   └── l10n/                          # chuẩn bị đa ngôn ngữ
├── test/
│   ├── crypto/                        # ★ test vector cho X25519 + AES-GCM
│   ├── features/
│   └── helper/
├── tool/
│   ├── ci.sh
│   └── seed_fake_data.dart            # tạo dữ liệu giả để demo
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml        # ★ cấu hình permission
│       └── kotlin/.../MainActivity.kt # FLAG_SECURE, MethodChannel nếu cần
├── docs/
│   ├── bao-cao/                      # các chương .md
│   ├── so-do/                         # UML, sơ đồ luồng
│   └── anh-chup/                      # ảnh demo
└── README.md
```

**Nguyên tắc phân lớp (để AI viết code đúng chỗ):**

```
presentation (UI)  →  repository (interface + impl)  →  service (Firebase, crypto, GPS)
        ↓                      ↓
   Riverpod Provider      Model (immutable, fromJson/toJson)
```

- **UI không bao giờ gọi Firebase trực tiếp** → chỉ gọi repository.
- **Repository không chứa logic mật mã** → logic ở `crypto_service`.
- **Model không biết gì về mạng**.

---

## 5. MILESTONE 1 — AUTH & VÒNG TRÒN GIA ĐÌNH (Tuần 1)

**Mục tiêu:** có app đăng nhập được, tạo vòng tròn, thêm thành viên, và dữ liệu nằm trong Firestore.

### 5.1. Sprint 1A — Auth (ưu tiên cao)

- Firebase Anonymous/Email+Password sign-in.
- `AuthRepository`: `signIn`, `signUp`, `signOut`, `currentUser`, `authStateChanges` stream.
- `AuthNotifier` (Riverpod) + màn hình Login/Register.
- **Refresh token** lưu `flutter_secure_storage`; access token lấy từ Firebase SDK.
- Auto sign-out khi token hết hạn → chuyển màn hình login.

### 5.2. Sprint 1B — Vòng tròn gia đình

- `CircleRepository`: `create`, `join` (bằng mã invite 6 ký tự), `listMembers`, `removeMember`, `setSharingPermission`.
- Model `FamilyCircle` + `CircleMember` (userId, displayName, role, canSeeLocation, joinedAt).
- Màn hình: danh sách vòng tròn, tạo vòng tròn, mời thành viên, cài đặt quyền chia sẻ.
- Firestore rules: chỉ thành viên mới đọc/ghi được `circles/{circleId}`.

### 5.3. Checklist bảo mật tuần 1

- [ ] Firestore Security Rules **không** dùng `allow read, write: if true`
- [ ] Rules chỉ cho phép thành viên trong `circle.members` đọc `locations/` của circle đó
- [ ] Mật khẩu không bao giờ log ra console
- [ ] Token lưu trong secure storage, kiểm tra bằng cách đọc file SharedPreferences thủ công (không thấy token)
- [ ] Test rules bằng Firebase Emulator Suite

**Tiêu chí nghiệm thu:** 2 máy thật đăng nhập 2 tài khoản, mỗi máy thấy vòng tròn và thành viên của máy kia trong Firestore, không thấy vòng tròn của người ngoài.

---

## 6. MILESTONE 2 — BẢN ĐỒ & VỊ TRÍ REALTIME (Tuần 2)

### 5.1. Sprint 2A — Bản đồ & vị trí

- `flutter_map` + `latlong2`.
- `geolocator`: xin quyền, lấy vị trí, stream cập nhật.
- `background_locator_2`: cập nhật nền khi app đóng (interval ~15s, minDistance ~20m).
- `LocationRepository`: `startSharing`, `stopSharing`, `watchPositions(circleId)`.
- Firestore collection `locations/{circleId}/pings/{userId}` — ghi đè (last known position) để không phình dữ liệu.
- UI: bản đồ + marker màu theo thành viên + panel danh sách.

### 6.2. Sprint 2B — Geofence

- `Geofence` model: tên, tâm (lat/lng), bán kính (mét), trạng thái bật/tắt.
- Tính khoảng cách bằng **công thức Haversine** (không phải Euclid — sai ở mức độ địa lý), demo trong báo cáo để chứng minh hiểu biết.
- So sánh trạng thái enter/exit giữa 2 lần cập nhật → tránh spam cảnh báo.
- UI: tạo/sửa/xóa geofence (chọn tâm trên bản đồ), hiển thị vòng tròn.

### 6.3. Checklist bảo mật tuần 2

- [ ] Kiểm tra mock location: `location.isMocked` → cảnh báo, ghi log
- [ ] Chỉ ghi vị trí khi người dùng **bật chia sẻ** → không tự ý thu thập
- [ ] Dữ liệu vị trí cũ tự xóa theo TTL (cron job Cloud Function hoặc Firestore TTL policy)
- [ ] Kiểm tra quyền runtime (background location) trước khi ghi

**Tiêu chí nghiệm thu:** 2 máy thật, mở app thấy marker của nhau cập nhật < 10s, tắt chia sẻ → máy kia mất marker sau < 10s, đặt geofence rồi đi ra khỏi vùng → nhận cảnh báo.

---

## 7. MILESTONE 3 — SOS (Tuần 3)

### 7.1. Sprint 3A — Luồng SOS

- Màn hình SOS: nút lớn, giữ 2 giây để kích hoạt (chống bấm nhầm), hủy được trong 2s.
- `SosRepository.send()`: đóng gói payload {lat, lng, timestamp, batteryLevel}, lưu `SOSEvent` vào Firestore, ghi audit.
- Cloud Function `onSOSCreated` → gửi FCM tới các thiết viên khác trong circle.
- Màn hình nhận SOS: bật màn hình, phát âm thanh lặn, hiển thị vị trí + nút "Tôi đã an toàn".
- Trạng thái SOS: `ACTIVE → ACKNOWLEDGED → RESOLVED`.

### 7.2. Sprint 3B — Ghi âm

- `record` package: ghi âm ~10–15s, mã hóa **trước khi upload** (xem M4).
- Upload lên Firebase Storage với tên ngẫu nhiên (không chứa thông tin nhận diện).
- Quyền `RECORD_AUDIO` xin runtime, giải thích rõ mục đích.

### 7.3. Checklist bảo mật tuần 3

- [ ] Rate limiting API SOS: tối đa 1 SOS / 30 giây / người dùng (kiểm tra ở Cloud Function)
- [ ] Chống spam: yêu cầu nonce/sequence chống replay
- [ ] SOS tự hết hạn sau 30 phút nếu không ai xác nhận → ẩn khỏi danh sách
- [ ] Kiểm tra quyền: chỉ thành viên cùng circle mới nhận thông báo SOS
- [ ] Không ghi log nội dung SOS dạng plaintext ra console

**Tiêu chí nghiệm thu:** máy A nhấn SOS → máy B nhận thông báo + vị trí trong < 5s, hiển thị trạng thái đã xem, có nhật ký "B đã xem SOS của A lúc HH:MM".

---

## 8. MILESTONE 4 — E2EE ★ ĐỘT NHẤN (Tuần 4)

> Đây là phần quyết định điểm số. Làm **chậm, làm đúng**. Đây là tuần có rủi ro cao nhất.

### 8.1. Sprint 4A — Lớp crypto (test trước, code sau)

**Nguyên tắc: viết test TRƯỚC, rồi viết code cho pass.**

| Test file | Nội dung test |
|---|---|
| `test/crypto/x25519_test.dart` | 2 cặp khóa → ECDH → cùng shared secret; khóa khác → secret khác |
| `test/crypto/aes_gcm_test.dart` | Round-trip encrypt/decrypt; **sai nonce → throw**; **sai key → throw**; ciphertext khác plaintext |
| `test/crypto/e2ee_payload_test.dart` | Payload location mã hóa → giải mã → khớp byte-for-byte |
| `test/crypto/nonce_test.dart` | 1000 lần encrypt cùng plaintext → 1000 ciphertext khác nhau (không tái sử dụng nonce) |

### 8.2. Sprint 4B — KeyService

```
KeyService
├── generateIdentityKeyPair()  → X25519, private key lưu secure_storage, public key upload
├── loadPublicKey(userId)
├── deriveSharedSecret(myPrivate, theirPublic) → 32 bytes
├── deriveSessionKey(sharedSecret) → HKDF-SHA256 → AES-256 key
└── rotateKeys()               # đổi cặp khóa → re-encrypt lịch sử
```

- Public key lưu ở `users/{uid}/publicKey`.
- Thêm thành viên → kéo public key của họ → tính shared key → lưu cục bộ (mã hóa).
- Shared key cache local, **mã hóa bằng secure storage**.

### 8.3. Sprint 4C — Mã hóa payload vị trí

```
plaintext: {"lat":21.0285,"lng":105.8542,"t":1730000000}
    ↓ JSON → UTF-8
    ↓ AES-256-GCM(key, nonce=random96bit, aad=circleId)
ciphertext = base64(nonce || tag || ciphertext)
```

- Firestore lưu **chỉ** ciphertext + metadata tối thiểu (timestamp server-side, sender id).
- **Không** lưu lat/lng dạng plaintext.
- Client giải mã khi hiển thị.

### 8.4. Sprint 4D — Consent + Audit log

- **Consent:** `users/{uid}/settings/sharingEnabled` + `circles/{id}/members/{uid}/canSeeLocation`. Tắt → Firestore rules chặn ghi → dữ liệu dừng ngay.
- **Audit log:** collection `auditLogs` ghi {viewerId, subjectId, circleId, action, timestamp}. Hiển thị màn hình "Ai đã xem vị trí của tôi" — theo thứ tự thời gian.
- Audit log cũng nên **mã hóa** để người ngoài không đọc được metadata.

### 8.5. Sprint 4E — Demo E2EE (khoảnh khắc quyết định)

**Kịch bản trình diễn chuẩn bị sẵn:**

1. Mở Firebase Console → Firestore → `locations/{circleId}`.
2. Chọn 1 document → hiển thị payload.
3. **Chỉ toàn bộ là base64/ciphertext**, không có tọa độ.
4. Quay màn hình, dán vào báo cáo chương 3.
5. *Thêm:* bật DevTools Firestore → thử sửa ciphertext → app báo lỗi giải mã → chứng minh tính toàn vẹn.

### 8.6. Checklist bảo mật tuần 4

- [ ] Mọi payload vị trí đều đi qua `crypto_service.encrypt()`, **không** có đường vòng nào ghi plaintext
- [ ] Nonce sinh bằng `Random.secure()`, 96-bit
- [ ] Private key **không** bao giờ gửi lên server
- [ ] Test: grep toàn bộ codebase, không có `lat:`/`lng:` nào ghi thẳng vào Firestore
- [ ] Shared key lưu mã hóa, không lưu plaintext trong shared_preferences
- [ ] Có bảng so sánh: có E2EE vs không E2EE (bảng minh hoạ trong báo cáo)

**Tiêu chí nghiệm thu:** Firestore **không chứa** tọa độ dạng đọc được; máy B vẫn thấy vị trí thật của A; audit log hiển thị đúng ai xem ai.

---

## 9. MILESTONE 5 — CHIA SẺ HÀNH TRÌNH & HARDENING (Tuần 5)

### 9.1. Sprint 5A — Chia sẻ hành trình (mã 6 số)

- Mã 6 chữ số sinh bằng `Random.secure()`, **băm** (Argon2/BCrypt) trước khi lưu → server không biết mã gốc.
- TTL mặc định 30 phút, tối đa 24 giờ, hết hạn tự vô hiệu.
- **Một lần dùng** (one-time): dùng xong → invalidate. Cơ chế chống chụp lại.
- Rate limiting: giới hạn số lần thử mã sai theo IP/device.
- Theo dõi: người nhận mã thấy vị trí người tạo trong thời gian hiệu lực.

### 9.2. Sprint 5B — Hardening

| Hạng mục | Cách làm |
|---|---|
| FLAG_SECURE | `window.setFlag(LayoutWindowParam.FLAG_SECURE, true)` khi vào màn hình nhạy cảm |
| Tự khóa app | `AppLifecycleState.paused` → yêu cầu xác thực sinh trắc học khi quay lại |
| Xác thực sinh trắc học | `local_auth` — xác thực trước khi xem vị trị người khác |
| Certificate pinning | `http` + `dio` với `badCertificateCallback` chặn (chỉ cho phép cert đã pin) |
| R8/ProGuard | bật minify trong `build.gradle`, kiểm tra log rò rỉ |
| Root/Debug detect | `su` binary check, `BuildConfig.DEBUG`, `debuggable` flag → cảnh báo |
| Logout tự động | Hết hạn token → xóa secure storage, quay về login |
| Xóa dữ liệu | Xóa cache vị trí khi đăng xuất; tự xóa dữ liệu cũ theo TTL |

### 9.3. Checklist bảo mật tuần 5

- [ ] Mã chia sẻ băm trước khi lưu — kiểm tra bằng cách đọc Firestore
- [ ] Mã hết hạn và bị vô hiệu sau 1 lần dùng
- [ ] FLAG_SECURE chặn được screenshot (kiểm tra bằng `adb shell screencap`)
- [ ] `flutter build apk --release` chạy được, log không lộ dữ liệu nhạy cảm
- [ ] Không còn log chứa token / tọa độ / ciphertext dài

**Tiêu chí nghiệm thu:** `adb shell screencap` trên màn hình vị trí → file ảnh đen/trống; mã chia sẻ dùng lần 2 → báo lỗi; APK release không crash.

---

## 10. MILESTONE 6 — KIỂM THỬ, TỐI ƯU, VIẾT BÁO CÁO (Tuần 6)

### 10.1. Sprint 6A — Kiểm thử tấn công (phần ăn điểm nhất)

> Đây là phần **không ai khác trong lớp làm**. Làm tốt → điểm cao.

| Tấn công | Cách kiểm tra | Kết quả mong đợi |
|---|---|---|
| Đọc dữ liệu người khác | Dùng tài khoản không thuộc circle, đọc Firestore trực tiếp | Bị Firestore rules chặn |
| Xem ciphertext | Mở Firestore Console | Không có tọa độ dạng rõ |
| Sửa ciphertext | DevTools Firestore sửa 1 byte | Giải mã thất bại → báo lỗi, cảnh báo |
| Nghe lén kênh | MITM proxy (Burp/mitmproxy) | TLS + pinning chặn, cert không khớp |
| Brute-force mã chia sẻ | Script thử 1 triệu mã | Bị rate limit + khóa tạm |
| Replay gói tin | Bắt lại request cũ gửi lại | Nonce/sequence + timestamp chặn |
| Chiếm session | Cố dùng access token đã thu hồi | 401 → buộc đăng nhập lại |
| Đọc DB cục bộ | `adb shell` pull file DB | SQLCipher → không đọc được |
| Chụp màn hình | `adb shell screencap` | Ảnh đen trên màn hình nhạy cảm |
| Root detection | Bật root trên emulator | App cảnh báo, hạn chế chức năng nhạy cảm |

**Ghi kết quả vào bảng trong báo cáo chương 3** — đây là bảng "vũ khí" của đồ án.

### 10.2. Sprint 6B — Tối ưu & đánh giá

- Đo độ trễ mã hóa (benchmark `cryptography`: đủ nhanh cho vị trí 5–10s).
- Đo độ trễ end-to-end SOS (nhấn → máy B nhận).
- Tối ưu pin: kiểm tra background locator, tắt khi không cần.
- Sửa hết warning từ `flutter analyze`.

### 10.3. Sprint 6C — Báo cáo (theo khung mục 6.1 của đề cương)

| Phần | Nội dung | Nguồn |
|---|---|---|
| Mở đầu | Bối cảnh, mục tiêu, phạm vi | Đề cương |
| Chương 1 | Cơ sở lý thuyết: E2EE, X25519, AES-GCM, HKDF, threat model | Tài liệu tham khảo + ghi chú môn học |
| Chương 2 | Phân tích & thiết kế: UC, kiến trúc, mô hình dữ liệu, sơ đồ luồng | Mã nguồn + sơ đồ tự vẽ |
| Chương 3 | Kết quả: ảnh chụp màn hình, **bảng tấn công**, đo hiệu năng | Sprint 6A/6B |
| Chương 4 | Kết luận & hướng phát triển | — |
| Phụ lục | Code quan trọng (crypto), log test tấn công | — |

**Suy nghĩ bắt buộc cho mỗi cơ chế bảo mật** (mẫu 3 câu, dùng cho cả 10 cơ chế):

1. **Đe dọa:** cơ chế này chống lại tấn công cụ thể nào?
2. **Cơ chế:** nó hoạt động thế nào trong hệ thống của tôi?
3. **Hạn chế:** nó **không** chống được gì?

> Câu 3 là điểm giáo viên phân biệt đồ án giỏi và trung bình. Đừng bỏ trống.

---

## 11. BACKLOG & ĐIỀU CHỈNH PHẠM VI

### 11.1. Nếu trượt tiến độ — cắt theo thứ tự này

| Ưu tiên cắt | Hạng mục | Lý do |
|---|---|---|
| 1️⃣ | Ghi âm trong SOS | Chỉ là "nice to have", vị trí + thông báo đã đủ |
| 2️⃣ | Chia sẻ hành trình mã 6 số | Chức năng phụ, không phải trọng tâm |
| 3️⃣ | Geofence | Có thể demo bằng bán kính đơn giản |
| 4️⃣ | Đồ thị thống kê / lịch sử chi tiết | UI phụ |
| 5️⃣ | Đa ngôn ngữ | Không cần cho đồ án |

### 11.2. KHÔNG BAO GIỜ cắt

- ✅ E2EE (X25519 + AES-GCM) — điểm nhấn
- ✅ Firestore Security Rules + kiểm thử bằng attack table
- ✅ Audit log / consent thu hồi được
- ✅ Băm mật khẩu / token secure storage
- ✅ Rate limiting
- ✅ Bảng kết quả kiểm thử tấn công trong báo cáo

### 11.3. Rủi ro đã biết & cách xử lý

| Rủi ro | Khả năng | Xử lý |
|--------|-----------|-------|
| Firebase quota (free tier) — nhiều nhóm dùng chung project | Cao | Tạo project riêng cho nhóm; dùng emulator khi dev; nếu vượt → switch sang Node.js + Express + SQLite |
| Emulator không có GPS | Trung bình | Dùng `adb emu geo fix <lat> <lng>` để giả lập; test thật trên thiết bị |
| Gradle build lần đầu quá lâu | Cao | Warm-up build ngay Tuần 0 |
| Build APK release lỗi R8 | Trung bình | Test `--release` từ sớm (Tuần 1), không để đến cuối |
| `google-services.json` commit nhầm lên Git | Thấp | `.gitignore` ngay từ đầu; dùng `flutterfire configure` |
| Không đủ 2 máy Android thật | Trung bình | Emulator + điện thoại thân; nếu chỉ 1 máy → demo bằng 2 app trên 2 emulator |
| Nhóm 3–4 người, phân công lệch | Cao | Chia theo milestone, mỗi người 1 milestone; review chéo |

---

## 12. CHECKLIST HÀNG TUẦN (dùng cho buổi họp nhóm)

Mỗi cuối tuần, mỗi người trả lời:

- [ ] Tuần này tôi hoàn thành những gì?
- [ ] Có gì **chư** hoàn thành, và tại sao?
- [ ] Mình có bị **block** ở đâu? (cần ai hỗ trợ)
- [ ] Tuần sau tôi sẽ làm gì?
- [ ] Có cơ chế bảo mật nào đã xong? → viết bằng 3 câu mẫu ở mục 10.3
- [ ] Tag git đã tạo? Video demo đã quay?

---

## 13. CHECKLIST KHI NỘP BÁO CÁO

- [ ] Báo cáo đủ 4 chương theo khung mẫu
- [ ] Mỗi cơ chế bảo mật có phân tích 3 câu (đe dọa / cơ chế / hạn chế)
- [ ] Có **bảng kết quả kiểm thử tấn công** (mục 10.1)
- [ ] Có ảnh chụp Firestore chứng minh E2EE (mục 8.5)
- [ ] Có sơ đồ: UC, kiến trúc, ER, luồng SOS, luồng khóa
- [ ] Mã nguồn chạy được: `flutter pub get && flutter build apk --release`
- [ ] `.gitignore` đúng, không lộ `google-services.json`
- [ ] Tài liệu tham khảo trích dẫn đúng chuẩn, ít nhất 8 nguồn (ưu tiên giáo trình + sách bảo mật)
- [ ] Slide bảo vệ 10–15 trang, có **một slide demo E2EE bằng ảnh thật**

---

## 14. BẮT ĐẦU NGAY — TUẦN 0

Thứ tự hành động ngay hôm nay:

```bash
# 1. Thêm Flutter vào PATH (persist)
echo 'export PATH="$HOME/dev/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 2. Kiểm tra
flutter doctor -v
flutter doctor --android-licenses   # nhập "y" cho tất cả

# 3. Tạo project
cd ~/dev
flutter create --org vn.atbm.sos --platforms=android sos_safe_family
cd sos_safe_family

# 4. Thêm dependencies cốt lõi
flutter pub add flutter_riverpod firebase_core firebase_auth cloud_firestore
flutter pub add firebase_messaging firebase_storage geolocator background_locator_2
flutter pub add cryptography cryptography_flutter flutter_secure_storage
flutter pub add flutter_map latlong2 local_auth sqflite_sqlcipher path_provider
flutter pub add intl uuid permission_handler

# 5. Dev dependencies
flutter pub add --dev mocktail

# 6. Warm-up build (LÂU - chạy 1 lần, để nền)
flutter build apk --debug

# 7. Chạy trên emulator
flutter emulators          # liệt kê, khởi tạo nếu cần
flutter emulators --launch <emulator_id>
flutter devices
flutter run

# 8. Firebase CLI
npm install -g firebase-tools
firebase login
firebase projects:list
dart pub global activate flutterfire_cli
flutterfire configure
```

Sau đó tôi sẽ viết cho bạn **từng file source** của Tuần 0 theo thứ tự, kèm prompt vibe code cụ thể để bạn dán vào.

---

## 15. GHI CHÚ NHANH VỀ TESTING

| Loại test | Công cụ | Ví dụ |
|-----------|---------|-------|
| Unit test logic | `flutter_test` | Tính Haversine, kiểm tra ràng buộc quota |
| Unit test crypto | `flutter_test` + test vector | X25519 shared secret, AES-GCM round-trip |
| Widget test | `flutter_test` | UI hiển thị danh sách thành viên |
| Integration test | `integration_test` | Đăng ký → tạo circle → thêm member (chạy trên emulator) |
| Rules test | Firebase Emulator + `@firebase/rules-unit-testing` | Truy cập trái phép bị chặn |
| Kiểm thử tấn công | Script thủ công + `mitmproxy` | Bảng mục 10.1 |

**Ưu tiên cao nhất:** test crypto (tuần 4) và rules test (tuần 1). Đây là 2 chỗ dễ sai nhất.

---

*— Hết kế hoạch —*
