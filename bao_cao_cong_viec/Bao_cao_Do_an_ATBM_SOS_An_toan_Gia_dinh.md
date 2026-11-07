# BÁO CÁO ĐỒ ÁN MÔN HỌC
# AN TOÀN VÀ BẢO MẬT TRONG PHÁT TRIỂN ỨNG DỤNG DI ĐỘNG

---

## ĐỀ TÀI:
# XÂY DỰNG ỨNG DỤNG "SOS & AN TOÀN GIA ĐÌNH" TÍCH HỢP MÃ HÓA ĐẦU CUỐI (E2EE) VÀ BẢO MẬT PHẦN CỨNG TRÊN THIẾT BỊ DI ĐỘNG

*Theo dõi vị trí và cầu cứu khẩn cấp mã hóa đầu cuối trên hệ điều hành Android*

---

### THÔNG TIN CHUNG

| Mục thông tin | Chi tiết |
|---|---|
| **Cơ quan chủ quản** | Ban Cơ yếu Chính phủ |
| **Đơn vị đào tạo** | Học viện Kỹ thuật Mật mã – Khoa Công nghệ Thông tin |
| **Môn học** | An toàn và Bảo mật trong Phát triển Ứng dụng Di động (ATBM) |
| **Lớp học phần** | L03 |
| **Giảng viên hướng dẫn** | TS./ThS. Thái Thị Thanh Vân |
| **Sinh viên thực hiện** | Phạm Văn Tùng (KMA) |
| **Năm thực hiện** | 2025 – 2026 |
| **Mã nguồn dự án** | `/home/tung/dev/sos_safe_family` (Flutter 3.x / Dart 3.13 / Android minSdk 10) |
| **Trạng thái kỹ thuật** | Hoàn thành toàn diện M0 → M8, **100/100 tests PASS**, `flutter analyze` 0 issue |

---

# LỜI NÓI ĐẦU

Trong kỷ nguyên số hóa mạnh mẽ và sự phổ cập sâu rộng của thiết bị thông minh, điện thoại di động đã trở thành vật bất ly thân của mỗi cá nhân, đóng vai trò là phương tiện liên lạc, dẫn đường và bảo đảm an toàn cuộc sống. Đặc biệt, đối với các nhóm đối tượng yếu thế như trẻ em, người cao tuổi hoặc những người làm việc trong môi trường nguy hiểm, các giải pháp công nghệ hỗ trợ giám sát vị trí thời gian thực và phát tín hiệu cứu hộ khẩn cấp (SOS) mang ý nghĩa nhân văn và giá trị thực tiễn vô cùng to lớn.

Tuy nhiên, mặt trái của các dịch vụ định vị thương mại hiện nay là sự xâm phạm nghiêm trọng đến quyền riêng tư cá nhân. Phần lớn các ứng dụng phổ thông chỉ dừng lại ở các biện pháp an ninh cơ bản như sử dụng JWT hay băm mật khẩu, trong khi toàn bộ tọa độ GPS, lịch sử di chuyển và thông tin cá nhân đều được lưu trữ dưới dạng văn bản rõ (plaintext) trên máy chủ tập trung. Điều này biến máy chủ trở thành mục tiêu béo bở của các cuộc tấn công mạng, hoặc tiềm ẩn nguy cơ rò rỉ thông tin từ chính nhân viên vận hành hệ thống.

Nhận thức sâu sắc được tầm quan trọng cốt lõi của tính bí mật và toàn vẹn dữ liệu vị trí — vốn là dữ liệu nhạy cảm phản ánh toàn bộ đời tư của con người, đề tài **"Xây dựng ứng dụng SOS & An toàn Gia đình tích hợp mã hóa đầu cuối (E2EE) và bảo mật phần cứng trên thiết bị di động"** được lựa chọn nghiên cứu và phát triển trong khuôn khổ môn học *An toàn và Bảo mật trong Phát triển Ứng dụng Di động* tại Học viện Kỹ thuật Mật mã.

Em xin bày tỏ lòng biết ơn chân thành và sâu sắc nhất tới **cô giáo Thái Thị Thanh Vân**, người đã tận tình định hướng phương pháp luận nghiên cứu, cung cấp những gợi mở học thuật sắc bén về mô hình bảo mật di động và luôn động viên, khích lệ em trong suốt quá trình hoàn thành đồ án này. Em cũng xin gửi lời cảm ơn tới các thầy cô giáo trong Khoa Công nghệ Thông tin – Học viện Kỹ thuật Mật mã đã trang bị cho em nền tảng kiến thức vững chắc về khoa học mật mã và an toàn thông tin.

Mặc dù đã dành nhiều tâm huyết và nỗ lực hoàn thiện từ kiến trúc lý thuyết đến kiểm thử thực nghiệm, đồ án chắc chắn khó tránh khỏi những thiếu sót nhất định. Em rất mong nhận được những ý kiến đóng góp quý báu từ quý thầy cô trong Hội đồng chấm đồ án để sản phẩm được hoàn thiện hơn nữa.

*Hà Nội, tháng 11 năm 2026*  
**Sinh viên thực hiện**  
*Phạm Văn Tùng*

---

# DANH MỤC TỪ VIẾT TẮT

| Viết tắt | Thuật ngữ đầy đủ (Tiếng Anh) | Diễn giải tiếng Việt |
|---|---|---|
| **AAD** | Additional Authenticated Data | Dữ liệu xác thực bổ sung |
| **AEAD** | Authenticated Encryption with Associated Data | Mã hóa có xác thực kèm dữ liệu liên kết |
| **AES** | Advanced Encryption Standard | Tiêu chuẩn mã hóa tiên tiến (FIPS 197) |
| **ATBM** | An toàn và Bảo mật | Môn học An toàn và Bảo mật ứng dụng di động |
| **CSPRNG** | Cryptographically Secure Pseudorandom Number Generator | Bộ sinh số ngẫu nhiên giả an toàn mật mã |
| **ECDH** | Elliptic Curve Diffie-Hellman | Giao thức trao đổi khóa Diffie-Hellman trên đường cong Elliptic |
| **E2EE** | End-to-End Encryption | Mã hóa đầu cuối (người gửi mã hóa, chỉ người nhận giải mã) |
| **FCM** | Firebase Cloud Messaging | Dịch vụ thông báo đẩy đám mây của Google Firebase |
| **GCM** | Galois/Counter Mode | Chế độ đếm Galois kết hợp mã hóa và xác thực toàn vẹn |
| **HKDF** | HMAC-based Key Derivation Function | Hàm rút khóa an toàn dựa trên HMAC (RFC 5869) |
| **JCE / JCA** | Java Cryptography Extension / Architecture | Kiến trúc & Mở rộng Mật mã Java trên nền tảng Android |
| **KMA** | Vietnam Academy of Cryptography Techniques | Học viện Kỹ thuật Mật mã |
| **MASVS** | Mobile Application Security Verification Standard | Tiêu chuẩn kiểm định bảo mật ứng dụng di động của OWASP |
| **MITM** | Man-in-the-Middle Attack | Tấn công kẻ đứng giữa |
| **OOB** | Out-of-Band Verification | Xác thực ngoài băng tần |
| **OSM** | OpenStreetMap | Nền tảng bản đồ mở toàn cầu |
| **RBAC** | Role-Based Access Control | Kiểm soát truy cập dựa trên vai trò |
| **STRIDE** | Spoofing, Tampering, Repudiation, Information disclosure, DoS, Elevation of privilege | Mô hình phân loại đe dọa an ninh của Microsoft |
| **TEE** | Trusted Execution Environment | Môi trường thực thi tin cậy phần cứng |
| **TTL** | Time-To-Live | Thời gian sống hiệu lực của gói tin |

---

# MỞ ĐẦU

## 1. Bối cảnh đề tài

Trong bối cảnh xã hội hiện đại tại Việt Nam, an toàn gia đình đang trở thành mối quan tâm hàng đầu của mọi tầng lớp nhân dân. Đặc biệt, đối với những gia đình có con nhỏ, cha mẹ già yếu hay người thân làm việc trong các ngành nghề có rủi ro cao (lái xe đường dài, giao hàng ca đêm, công trình ngầm), nhu cầu theo dõi vị trí liên tục và phát tín hiệu kêu cứu khẩn cấp khi gặp sự cố hiểm nghèo là một đòi hỏi vô cùng cấp bách.

Tuy nhiên, khảo sát các ứng dụng định vị người thân và giám sát gia đình hiện hữu trên thị trường (như Life360, Find My Kids, Zenly trước đây) cho thấy một lỗ hổng bảo mật cố hữu: **toàn bộ dữ liệu vị trí thô được truyền tải và lưu trữ dưới dạng văn bản rõ (plaintext) trên máy chủ đám mây**. Máy chủ nắm giữ toàn quyền kiểm soát cơ sở dữ liệu và khóa giải mã, trong khi người dùng hoàn toàn không có công cụ hay phương tiện kỹ thuật nào để kiểm chứng xem tọa độ cá nhân của mình có bị lạm dụng hay không.

Hệ quả xã hội là nguy cơ xâm phạm đời tư không chỉ bắt nguồn từ các tin tặc bên ngoài mà còn xuất phát từ chính những tổ chức, nhà mạng hoặc cá nhân quản trị lưu trữ dữ liệu. Một khi dữ liệu vị trí tích lũy qua thời gian bị rò rỉ, đối tượng xấu có thể suy luận chính xác địa chỉ nhà riêng, trường học của con cái, lộ trình di chuyển hàng ngày và các mối quan hệ xã hội phức tạp. Vì vậy, việc áp dụng nguyên lý **Zero Trust** và **Mã hóa đầu cuối (E2EE)** nhằm chuyển dịch ranh giới tin cậy về tận thiết bị đầu cuối của người dùng là một yêu cầu mang tính sống còn.

## 2. Lý do lựa chọn đề tài

Đề tài **"SOS & An toàn Gia đình"** được lựa chọn triển khai xuất phát từ 4 lý do chiến lược:

1. **Giá trị xã hội và tính nhân văn trực tiếp:** Trẻ em và người cao tuổi là hai nhóm đối tượng có nguy cơ cao nhất đối với các tình huống bắt cóc, bạo lực, tai nạn hoặc lạc đường. Trong những khoảnh khắc sinh tử đó, từng giây trôi qua đều quyết định sự an nguy của nạn nhân. Đồ án giải quyết đồng thời bài toán cân bằng tinh tế: Ứng dụng phải **"cứu được"** (kích hoạt báo động tức thì không rào cản cản trở) nhưng đồng thời phải **"bảo vệ được"** (không để rò rỉ dữ liệu vị trí cho bất kỳ bên trung gian nào).
2. **Hàm lượng chuyên môn Mật mã và An toàn thông tin sâu sắc:** Đề tài là sự tổng hòa của các trụ cột tri thức thuộc môn học ATBM: Mật mã học ứng dụng (trao đổi khóa ECDH Curve25519, hàm rút khóa HKDF-SHA256, mã hóa xác thực AES-256-GCM), An toàn phần cứng di động (Android Keystore TEE/StrongBox, Scoped Biometrics, `FLAG_SECURE`), và Kỹ thuật phòng thủ chủ động (Anti-replay, Root Detection, Mock GPS Detection).
3. **Tính kiểm chứng định lượng và đo lường thực nghiệm:** Khác với các đề tài lý thuyết trừu tượng, mọi cơ chế bảo vệ trong đồ án đều được kiểm chứng thông qua một bộ kịch bản tấn công thực nghiệm tự động (bit-flipping, replay packets, giả mạo GPS, mạo danh khóa) và được đo đạc chính xác bằng benchmark hiệu năng mật mã.
4. **Điểm nhấn khác biệt trong học phần ATBM:** Đa phần các đồ án di động thông thường chỉ dừng lại ở giao thức HTTPS cơ bản kết hợp JWT và băm mật khẩu trên server. Ứng dụng này tiên phong hiện thực hóa mô hình **"Server chỉ là Relay — Không đọc được dữ liệu"** kết hợp kiến trúc **Emergency Bypass (Zero Barrier)**, có thể chứng minh một cách tường minh qua việc dữ liệu hiển thị trên Cloud Firestore hoàn toàn là chuỗi ciphertext vô nghĩa.

## 3. Mục tiêu nghiên cứu và phát triển

- Xây dựng một ứng dụng Android hoàn chỉnh bằng Flutter framework, đáp ứng các chức năng cốt lõi: Theo dõi vị trí thời gian thực trên bản đồ vệ tinh/vector, Phát cảnh báo SOS khẩn cấp, Quản lý Geofence vùng an toàn (nhà, trường học), Chia sẻ hành trình ngắn hạn qua mã 6 số OTP, Quản lý vòng tròn gia đình, Chat E2EE nội bộ và Nhật ký kiểm toán minh bạch.
- Thiết lập hệ thống bảo mật đa lớp lấy **Mã hóa đầu cuối (E2EE)** làm hạt nhân: Khóa riêng tư X25519 được sinh và lưu trữ an toàn trong phần cứng Android Keystore, máy chủ chỉ giữ vai trò chuyển tiếp các gói tin mã hóa AES-256-GCM.
- Triển khai cơ chế xác thực Out-of-band thông qua **Mã vân tay khóa công khai (SHA-256 Key Fingerprinting)**, triệt tiêu nguy cơ tấn công kẻ đứng giữa (MITM) khi người dùng trao đổi khóa lần đầu.
- Xây dựng mô hình phân tích đe dọa toàn diện theo tiêu chuẩn **STRIDE** của Microsoft, đồng thời thiết kế bộ kiểm thử bảo mật tự động đạt **100/100 tests PASS** với 0 cảnh báo linter.

## 4. Đối tượng và phạm vi nghiên cứu

- **Đối tượng sử dụng:** Các thành viên trong gia đình hạt nhân hoặc mở rộng, đặc biệt chú trọng trẻ vị thành niên, người già suy giảm trí nhớ, và người lao động di chuyển khuya.
- **Phạm vi kỹ thuật:**
  - Nền tảng đích: Hệ điều hành Android (hỗ trợ từ Android 10 / API Level 29 trở lên).
  - Bản đồ và định vị: Sử dụng thư viện `flutter_map` tích hợp dữ liệu OpenStreetMap (OSM) trực tuyến; Geofence sử dụng công thức tính khoảng cách mặt cầu Haversine chuẩn xác.
  - Sinh trắc học: Khai thác API native `BiometricPrompt` của Android (nhận diện vân tay hoặc khuôn mặt) cho các vùng dữ liệu nhạy cảm.
  - Phân phối ứng dụng: Triển khai trực tiếp file gói APK debug/release chuẩn hóa.

---

# CHƯƠNG 1 — CƠ SỞ LÝ THUYẾT VỀ AN TOÀN VÀ BẢO MẬT DI ĐỘNG

## 1.1. Tổng quan an toàn thông tin trên nền tảng di động

Môi trường thực thi của ứng dụng di động có những đặc thù rủi ro hoàn toàn khác biệt so với các hệ thống máy chủ doanh nghiệp truyền thống:
1. **Thiết bị hoạt động trong môi trường thù địch (Hostile Environment):** Thiết bị di động dễ bị thất lạc, đánh cắp vật lý, hoặc bị can thiệp bởi chính người dùng thông qua việc Root máy/Jailbreak nhằm vượt qua các cơ chế kiểm soát bảo mật của hệ điều hành.
2. **Kênh truyền thông không tin cậy:** Thiết bị thường xuyên kết nối qua các mạng Wi-Fi công cộng không có mật khẩu hoặc mạng di động của nhà mạng, nơi các cuộc tấn công nghe lén (Eavesdropping), bắt gói tin (Sniffing) và giả mạo máy chủ (DNS Spoofing / MITM) luôn tiềm ẩn.
3. **Mô hình Zero Trust đối với máy chủ lưu trữ:** Trong kiến trúc an toàn di động hiện đại (theo chuẩn NIST SP 800-207), máy chủ trung gian không được coi là một thực thể tin cậy tuyệt đối. Nếu máy chủ nắm giữ khóa giải mã hoặc dữ liệu văn bản rõ, một sự cố rò rỉ cơ sở dữ liệu (data breach) hoặc sự can thiệp của quản trị viên nội bộ sẽ làm phá sản toàn bộ tính riêng tư của hệ thống.

Do đó, ba nguyên lý kiến trúc bắt buộc phải được áp dụng:
- **Dữ liệu nhạy cảm phải được mã hóa đầu cuối (E2EE):** Chỉ người gửi và người nhận hợp pháp sở hữu khóa giải mã; máy chủ chỉ làm chức năng định tuyến (blind relay).
- **Khóa bí mật phải được neo giữ trong phần cứng an toàn:** Khóa riêng tư không được phép lưu trữ dưới dạng file văn bản hay SharedPreferences thông thường mà phải được niêm phong trong Android Keystore (TEE/StrongBox).
- **Tính toàn vẹn của thiết bị là tiên quyết:** Ứng dụng phải có khả năng tự kiểm tra trạng thái root và phát hiện vị trí GPS giả lập để đánh giá mức độ tin cậy của dữ liệu đầu vào.

## 1.2. Các nguyên lý mật mã sử dụng trong đồ án

```
+-----------------------------------------------------------------------------+
|                          NGUYÊN LÝ MẬT MÃ TRONG ĐỒ ÁN                       |
+-----------------------------------------------------------------------------+
|                                                                             |
|  [ Curve25519 (X25519) ] ---> Trao đổi khóa Diffie-Hellman không đối xứng    |
|             |                                                               |
|             v                                                               |
|  [   HKDF-SHA256       ] ---> Rút khóa phiên đối xứng 256-bit (32-byte salt)|
|             |                                                               |
|             v                                                               |
|  [   AES-256-GCM       ] ---> Mã hóa xác thực (AEAD): Nonce 96-bit + Tag 128|
|             |                                                               |
|             v                                                               |
|  [ SHA-256 Fingerprint ] ---> Vân tay khóa công khai xác thực ngoài băng    |
|                                                                             |
+-----------------------------------------------------------------------------+
```

### 1.2.1. Thỏa thuận khóa Diffie-Hellman trên Curve25519 (X25519)

Giao thức trao đổi khóa X25519 (RFC 7748) do nhà mật mã học Daniel J. Bernstein phát triển, hoạt động trên đường cong Montgomery được định nghĩa bởi phương trình:

$$y^2 = x^3 + 486662x^2 + x$$

trên trường hữu hạn nguyên tố $\mathbb{F}_p$ với $p = 2^{255} - 19$.

**Ưu điểm vượt trội so với các đường cong Weierstrass truyền thống (NIST P-256):**
- **Hiệu năng và Tốc độ:** Thuật toán sử dụng phép nhân thang Montgomery (Montgomery ladder) chỉ thao tác trên tọa độ hoành độ $x$, giúp loại bỏ hoàn toàn nhu cầu tính toán tọa độ tung độ $y$. Phép toán chỉ bao gồm các phép nhân và cộng trên trường hữu hạn, đạt tốc độ xử lý nhanh hơn từ 2 đến 4 lần so với NIST P-256 trên kiến trúc CPU ARM của di động.
- **Khả năng kháng tấn công kênh kề (Side-Channel Resistance):** Thuật toán chạy trong thời gian hằng số (constant-time execution), không có các rẽ nhánh điều kiện phụ thuộc vào giá trị của bit khóa bí mật, miễn nhiễm với các kỹ thuật tấn công đo thời gian (Timing Attack) và phân tích năng lượng (Power Analysis).
- **An toàn xoắn (Twist Security):** Curve25519 được thiết kế có tính an toàn xoắn hai chiều (twist-secure), ngăn chặn triệt để các cuộc tấn công gửi điểm thuộc đường cong xoắn yếu (invalid curve attack) mà không cần bước kiểm tra điểm hợp lệ phức tạp.
- **Loại bỏ nguy cơ Backdoor:** Không giống như các hằng số sinh ngẫu nhiên khó giải thích của chuẩn NIST, các hệ số của Curve25519 được lựa chọn minh bạch dựa trên tiêu chí toán học chặt chẽ.

**Cơ chế hoạt động trong đồ án:** Mỗi người dùng khi đăng nhập sẽ sinh một cặp khóa X25519 gồm Private Key ($k_{priv} \in [0, 2^{256}-1]$ đã được kẹp bit - clamped) và Public Key ($K_{pub} = k_{priv} \cdot G$). Khi hai thành viên A và B muốn giao tiếp an toàn:

$$\text{SharedSecret} = X25519(k_{priv}^A, K_{pub}^B) = X25519(k_{priv}^B, K_{pub}^A)$$

Bên thứ ba hoặc máy chủ chuyển tiếp dù thu thập được cả $K_{pub}^A$ và $K_{pub}^B$ trên đường truyền cũng không thể tìm được $\text{SharedSecret}$ do độ khó tính toán của bài toán Logarithm rời rạc trên đường cong Elliptic (ECDLP).

### 1.2.2. Hàm rút khóa HKDF-SHA256 (RFC 5869)

Khóa bí mật dùng chung $\text{SharedSecret}$ sinh ra từ phép nhân điểm X25519 có độ dài 32 byte nhưng phân phối entropy chưa đồng đều tuyệt đối theo tiêu chuẩn mật mã học. Do đó, việc sử dụng trực tiếp làm khóa mã hóa AES là không an toàn. Đồ án áp dụng chuẩn HKDF (HMAC-based Extract-and-Expand Key Derivation Function) bao gồm 2 bước:

1. **Giai đoạn Trích xuất (Extract):** Tạo khóa giả ngẫu nhiên PRK (Pseudorandom Key) có độ dài 256-bit:
   $$\text{PRK} = \text{HMAC-SHA256}(\text{salt}, \text{SharedSecret})$$
2. **Giai đoạn Mở rộng (Expand):** Rút ra khóa đối xứng phiên phục vụ mã hóa:
   $$\text{OKM} = \text{HMAC-SHA256}(\text{PRK}, \text{info} \parallel \text{0x01})$$
   với $\text{info} = \text{"sos\_safe\_family\_aes\_key"}$.

**Xử lý lỗi kỹ thuật sâu: Lỗi "Empty Key" trên Android JCE:**
Theo lý thuyết RFC 5869, tham số `salt` trong bước `Extract` có thể để rỗng (chiều dài 0). Tuy nhiên, trên hệ điều hành Android, bộ cung cấp mật mã Java Cryptography Extension (JCE) của một số nhà sản xuất thiết bị (như Samsung Knox hoặc Xiaomi MIUI) từ chối khởi tạo đối tượng `SecretKeySpec` với mảng byte rỗng và ném ra biệt lệ nghiêm trọng: `java.security.InvalidKeyException: Empty key`. Điều này khiến ứng dụng chạy tốt trên môi trường test máy tính nhưng lại bị crash trên thiết bị thật.

Để giải quyết triệt để lỗi này mà vẫn đảm bảo tính tương thích toán học 100% với RFC 5869, mã nguồn của đồ án sử dụng một mảng cố định gồm 32 byte `0x00`:
```dart
_hkdf.deriveKey(
  secretKey: sharedSecret,
  nonce: Uint8List(32), // Salt 32 byte 0x00 — tương đương chuẩn RFC 5869, khắc phục triệt để lỗi JCE
  info: utf8.encode('sos_safe_family_aes_key'),
);
```

### 1.2.3. Tiêu chuẩn mã hóa xác thực AES-256-GCM (NIST SP 800-38D)

AES-256-GCM là cơ chế mã hóa có xác thực (Authenticated Encryption with Associated Data - AEAD) kết hợp giữa chế độ đếm CTR của thuật toán AES và hàm băm xác thực vạn năng GHASH trên trường Galois $GF(2^{128})$ với đa thức tối thiểu:

$$P(x) = x^{128} + x^7 + x^2 + x + 1$$

Mỗi lần thực thi mã hóa, thuật toán yêu cầu:
- **Nonce (Number used ONCE):** 96-bit (12 byte), được sinh ngẫu nhiên độc lập bằng bộ sinh số an toàn mật mã CSPRNG.
- **Ciphertext:** Bản mã của dữ liệu vị trí/SOS/tin nhắn.
- **Authentication Tag:** Mã xác thực toàn vẹn 128-bit (16 byte).

**Tính chất then chốt:** Thao tác giải mã sẽ tự động thất bại và ném ngoại lệ `SecretBoxAuthenticationError` nếu có bất kỳ sự can thiệp nào vào bản mã (dù chỉ đổi 1 bit), sửa đổi nonce, hay tráo đổi tag xác thực. 

**Hiểm họa tái sử dụng Nonce (Nonce Reuse Catastrophe):** Trong chế độ GCM, nếu một cặp $(\text{Key}, \text{Nonce})$ bị tái sử dụng cho hai bản rõ khác nhau, kẻ tấn công có thể thực hiện phép XOR hai bản mã để thu được XOR của hai bản rõ ($C_1 \oplus C_2 = P_1 \oplus P_2$), đồng thời suy ra khóa băm GHASH $H = \text{AES}_K(0^{128})$, từ đó giả mạo hoàn toàn mã xác thực của các gói tin tiếp theo. Đồ án ngăn chặn rủi ro này bằng cách: mỗi lần mã hóa vị trí hay phát SOS đều bắt buộc gọi `Random.secure()` để sinh nonce 96-bit mới, triệt tiêu xác suất trùng lặp ($1/2^{96}$).

### 1.2.4. Xác thực Ngoài băng tần (OOB) bằng SHA-256 Key Fingerprint

Một hạn chế căn bản của giao thức trao đổi khóa Diffie-Hellman là **không tự xác thực danh tính đối tác**. Nếu kẻ tấn công đứng ở giữa đường truyền (MITM), hắn có thể chặn gói tin trao đổi khóa của Alice và Bob, sau đó giả mạo tạo hai phiên thỏa thuận khóa riêng rẽ với từng bên.

Để giải quyết vấn đề này mà không cần xây dựng hạ tầng khóa công khai (PKI) cồng kềnh, đồ án áp dụng cơ chế xác minh ngoài băng tần (Out-of-band Verification) thông qua **Mã vân tay khóa công khai SHA-256** (tương tự cơ chế Safety Number của Signal hay WhatsApp):

$$\text{Fingerprint} = \text{SHA-256}(K_{pub})[0..15] \longrightarrow \text{Format: } \text{8 cụm Hex viết hoa}$$

Ví dụ: `4A:8F:B1:C2:3D:9E:07:55`. Khi thêm thành viên vào gia đình, hai người có thể gặp mặt trực tiếp hoặc đối chiếu mã vân tay này qua một kênh liên lạc độc lập (như gọi điện thoại hoặc quét QR). Nếu mã vân tay khớp nhau 100%, kết nối được bảo đảm tuyệt đối không bị can thiệp bởi MITM.

---

## 1.3. Cơ chế bảo vệ phần cứng và hệ điều hành Android

```
+-----------------------------------------------------------------------------+
|                      KIẾN TRÚC BẢO MẬT PHẦN CỨNG ANDROID                    |
+-----------------------------------------------------------------------------+
|                                                                             |
|  [ Linux Kernel / Android OS ]  <--- Không gian người dùng bình thường     |
|             |                                                               |
|    (MethodChannel / IPC)                                                    |
|             v                                                               |
|  [ TEE / StrongBox Keymaster ]  <--- Môi trường bảo mật phần cứng cô lập    |
|             |                                                               |
|      +------+---------------------------------+                             |
|      |                                        |                             |
|      v                                        v                             |
|  [ X25519 Private Key ]              [ Keystore Master Key ]                |
|  (Không thể trích xuất ra RAM)        (Hardware-backed AES-256)             |
|                                                                             |
+-----------------------------------------------------------------------------+
```

### 1.3.1. Android Keystore System và Key Provisioning tự động (Milestone 8)

Hệ thống Android Keystore cho phép lưu trữ các khóa mật mã bên trong các phân vùng phần cứng chuyên dụng như Môi trường thực thi tin cậy (TEE - Trusted Execution Environment) hoặc chip bảo mật độc lập StrongBox Keymaster (đáp ứng tiêu chuẩn bảo mật phần cứng FIPS 140-2 Level 1/2). 

Trong Milestone 8, đồ án đã hiện thực hóa pipeline **Key Provisioning** hoàn chỉnh:
- Khi người dùng đăng nhập bằng tài khoản Google, `AuthService` kiểm tra xem thiết bị đã có cặp khóa X25519 gắn với định danh người dùng `user_private_key_{uid}` hay chưa.
- Nếu chưa có (lần đầu đăng nhập), hệ thống tự động sinh cặp khóa mới, mã hóa khóa riêng và niêm phong trong Android Keystore thông qua thư viện `flutter_secure_storage` với cấu hình an toàn phần cứng:
  ```dart
  AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  )
  ```
- Khóa riêng tư **không bao giờ được gửi qua mạng hay xuất ra bộ nhớ ngoài**, chỉ có khóa công khai được đồng bộ lên Cloud Firestore tại đường dẫn `users/{uid}/publicKey`.
- Cơ chế bảo đảm tính Idempotency: Người dùng đăng nhập lại trên cùng thiết bị sẽ tái sử dụng khóa Keystore đã có, không bị mất khả năng giải mã dữ liệu cũ.

### 1.3.2. Xác thực Sinh trắc học Scoped Biometrics qua Native BiometricPrompt

Hệ thống sử dụng thư viện `local_auth` để gọi trực tiếp giao diện xác thực sinh trắc học chuẩn của Android (`BiometricPrompt`), hỗ trợ cảm biến vân tay phần cứng và nhận diện khuôn mặt 3D. 

Điểm sáng tạo của đồ án là áp dụng nguyên tắc **Scoped Gate**: Sinh trắc học không bị áp đặt bừa bãi gây ức chế trải nghiệm, mà được phân vùng bảo vệ chặt chẽ cho các tác vụ nhạy cảm:
- Xem danh sách thành viên và phân quyền trong Vòng tròn gia đình.
- Truy cập Nhật ký kiểm toán và cảnh báo an ninh.
- Xem lại lịch sử tin nhắn Chat mã hóa E2EE.
- Cấu hình các thiết lập bảo mật và khóa ứng dụng.

### 1.3.3. Bảo vệ giao diện và chống rò rỉ dữ liệu qua Native FLAG_SECURE

Các ứng dụng định vị thông thường rất dễ bị tấn công chụp lén màn hình bởi các mã độc gián điệp chạy ngầm hoặc bị lưu ảnh chụp cache trong danh sách ứng dụng gần đây (Recent Apps Task Switcher). 

Đồ án xử lý vấn đề này bằng mã nguồn native Kotlin trong `MainActivity.kt`:
```kotlin
window.setFlags(
    WindowManager.LayoutParams.FLAG_SECURE,
    WindowManager.LayoutParams.FLAG_SECURE
)
```
Mã lệnh này can thiệp trực tiếp vào hệ thống quản lý cửa sổ Android SurfaceFlinger, ra lệnh:
1. Chặn hoàn toàn thao tác chụp màn hình (Screenshot) và quay video màn hình (Screen Recording) của hệ điều hành.
2. Che trắng hoặc làm mờ cửa sổ ứng dụng khi người dùng chuyển sang trình đa nhiệm (Task Switcher), ngăn ngừa việc chụp trộm màn hình nền.

### 1.3.4. Phòng thủ chủ động: Phát hiện Root và Giả mạo vị trí (Mock GPS)

- **Phát hiện Root Thiết bị:** `NativeSecurityService` phối hợp với mã nguồn native kiểm tra sự hiện diện của nhị phân cấp quyền `su` tại 8 vị trí hệ thống trọng yếu (`/system/bin/su`, `/system/xbin/su`, `/sbin/su`, `/system/sbin/su`, `/data/local/xbin/su`, v.v.) kết hợp kiểm tra nhãn build của kernel (`test-keys` / `dev-keys`). Khi phát hiện thiết bị đã bị root, hệ thống lập tức đặt trạng thái `isTrusted = false` trên thẻ `TamperReport` và đưa ra cảnh báo đỏ trong Nhật ký kiểm toán.
- **Phát hiện Vị trí Giả lập (Mock GPS):** Khai thác cờ `Position.isMocked` từ API Android Location Services (`TamperDetector.isMockLocation`). Khi người dùng bật Developer Options và chọn ứng dụng Fake GPS, cờ này sẽ được kích hoạt, hệ thống lập tức gắn nhãn cảnh báo gian lận và thông báo cho người thân trong vòng tròn.

---

# CHƯƠNG 2 — PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG

## 2.1. Phân tích yêu cầu hệ thống

### 2.1.1. Yêu cầu chức năng

| Mã | Tên chức năng | Mô tả chi tiết | Trạng thái kỹ thuật |
|---|---|---|---|
| **F-01** | Quản lý vòng tròn gia đình | Tạo nhóm, thêm thành viên, phân quyền chia sẻ vị trí, quản lý trạng thái online | Đã hoàn thành |
| **F-02** | Định vị thời gian thực | Hiển thị tọa độ chính xác của người thân trên bản đồ OpenStreetMap, tự động cập nhật chu kỳ | Đã hoàn thành |
| **F-03** | Báo động SOS khẩn cấp | Kích hoạt báo động khẩn cấp tức thì khi nhấn giữ nút 2 giây, đếm ngược 3s có âm thanh/rung | Đã hoàn thành |
| **F-04** | Thiết lập Geofence vùng an toàn | Đặt tâm và bán kính vùng an toàn (nhà riêng, trường học); cảnh báo khi ra/vào vùng | Đã hoàn thành |
| **F-05** | Chia sẻ hành trình tạm thời | Sinh mã 6 số OTP bằng CSPRNG, lưu trữ dưới dạng băm SHA-256 có thời hạn (TTL 60 phút) | Đã hoàn thành |
| **F-06** | Chat gia đình bảo mật E2EE | Nhắn tin trao đổi văn bản và hình ảnh nội bộ gia đình mã hóa đầu cuối hai chiều | Đã hoàn thành |
| **F-07** | Quản lý danh tính & Đăng nhập | Tích hợp Google Sign-In, Firebase Auth, tự động khởi tạo cặp khóa X25519 Keystore | Đã hoàn thành (M8) |
| **F-08** | Nhật ký kiểm toán an toàn | Ghi vết minh bạch mọi sự kiện truy cập vị trí, phát SOS, và phát hiện tấn công | Đã hoàn thành |

### 2.1.2. Yêu cầu phi chức năng

- **Độ trễ xử lý mật mã:** Thời gian thực thi cho mỗi thao tác mã hóa/giải mã tọa độ và tin nhắn phải dưới **10 ms** để không gây giật lag giao diện (kết quả thực nghiệm thực tế đạt < 0,15 ms).
- **Chu kỳ cập nhật:** Tọa độ GPS được cập nhật định kỳ mỗi 10 giây (`AppConstants.locationInterval`), tích hợp bộ lọc khoảng cách 20m nhằm tối ưu hóa thời lượng pin.
- **Tính khả dụng cao:** Ứng dụng hoạt động mượt mà ngay cả khi mất kết nối mạng (chế độ offline lưu trữ đệm và đồng bộ khi có mạng lại).
- **Tuân thủ tiêu chuẩn mã nguồn:** Bộ quy tắc linting `flutter_lints` 6.0 nghiêm ngặt đạt **0 cảnh báo**.

---

## 2.2. Thiết kế kiến trúc hệ thống

### 2.2.1. Kiến trúc 3 tầng và Ranh giới tin cậy (Trust Boundary)

Hệ thống được thiết kế theo mô hình kiến trúc phân tầng rõ rệt, trong đó **Ranh giới tin cậy (Trust Boundary)** được đặt ngay tại cổng ra của ứng dụng di động:

```
+-----------------------------------------------------------------------------------+
|               TẦNG THIẾT BỊ KHÁCH (ANDROID CLIENT - TRUSTED DOMAIN)               |
|                                                                                   |
|  [ Giao diện Flutter ] <---> [ AppState (Quản lý trạng thái) ]                    |
|                                     |                                             |
|        +----------------------------+-----------------------------+               |
|        v                            v                             v               |
|  [ CryptoService ]         [ NativeSecurityService ]       [ ReplayGuard ]        |
|   (X25519 + AES-GCM)        (Keystore / FLAG_SECURE)        (Anti-replay)         |
|        |                            |                                             |
|        +----------------------------+---------------------------------------------+
+-----------------------------------------------------------------------------------+
                                      |
                     [ RANH GIỚI TIN CẬY (TRUST BOUNDARY) ]
                                      | (Chỉ truyền Ciphertext & Metadata)
                                      v
+-----------------------------------------------------------------------------------+
|               TẦNG MÁY CHỦ TRUNG GIAN (CLOUD RELAY - UNTRUSTED DOMAIN)            |
|                                                                                   |
|  - Firebase Cloud Firestore (Chỉ lưu trữ Bản mã Base64, Nonce, MAC, Public Key)   |
|  - Firebase Authentication & Google OAuth (Xác thực danh tính tài khoản)          |
|  - Firebase Cloud Messaging - FCM (Đẩy thông báo cảnh báo SOS khẩn cấp)           |
+-----------------------------------------------------------------------------------+
                                      |
                                      v
+-----------------------------------------------------------------------------------+
|            TẦNG THIẾT BỊ NGƯỜI NHẬN (RECIPIENT CLIENT - TRUSTED DOMAIN)           |
|                                                                                   |
|  [ Nhận Ciphertext ] ---> [ ReplayGuard kiểm tra ] ---> [ Giải mã bằng Private Key]
+-----------------------------------------------------------------------------------+
```

**Quy tắc thiết kế cốt lõi:** Máy chủ hoàn toàn **bị mù (Blind Server)** đối với dữ liệu nội dung. Mọi payload gửi lên máy chủ đều ở dạng Base64 của cấu trúc `nonce + mac + ciphertext`. Dù máy chủ bị hack hay cơ sở dữ liệu bị lộ, kẻ tấn công cũng chỉ thu được các chuỗi byte ngẫu nhiên không có khả năng khai thác.

### 2.2.2. Kiến trúc Emergency Bypass (Triết lý Zero Barrier)

Trong các thiết kế phần mềm bảo mật truyền thống, việc đòi hỏi người dùng phải đăng nhập mật khẩu phức tạp hoặc quét vân tay mỗi khi mở ứng dụng tạo ra một **rào cản chết người** trong các tình huống hiểm nghèo (nạn nhân đang bị khống chế, bị thương, hoặc hoảng loạn không thể mở khóa sinh trắc học).

Đồ án giải quyết triệt để mâu thuẫn này bằng kiến trúc **Emergency Bypass**:
1. **Zero Barrier (Không rào cản cứu hộ):** Khi khởi động ứng dụng, người dùng được đưa thẳng vào `MapScreen` với nút bấm SOS nổi bật. Nút SOS được thiết kế kích hoạt bằng thao tác nhấn giữ 2 giây (`sosHoldDuration`) nhằm ngăn ngừa việc bấm nhầm, đi kèm màn hình đếm ngược 3 giây có rung chuông cảnh báo và nút HỦY khẩn cấp.
2. **Scoped Gate (Khóa vùng thông tin nhạy cảm):** Toàn bộ các dữ liệu liên quan đến đời tư gia đình (danh sách thành viên, nhật ký di chuyển, cấu hình bảo mật) đều được khóa chặt phía sau bức tường sinh trắc học `BiometricPrompt`.

```
                    Khởi động Ứng dụng
                            |
                            v
                  +--------------------+
                  |     MapScreen      | <--- HOÀN TOÀN KHÔNG RÀO CẢN
                  |  (Bản đồ & Nút SOS)|      (Zero Barrier - Luôn sẵn sàng)
                  +--------------------+
                            |
            +---------------+---------------+
            |                               |
    [ Nhấn giữ SOS 2s ]             [ Chọn Tab Riêng Tư ]
            |                       (Vòng tròn, Lịch sử, Cài đặt)
            v                               |
  SosCountdownScreen (3-2-1)                v
            |                      +--------------------+
            v                      |  Biometric Prompt  |
     Gửi SOS Mã hóa E2EE           | (Vân tay / Face ID)|
                                   +--------------------+
                                            |
                                            v (Xác thực thành công)
                                   Truy cập dữ liệu nhạy cảm
```

### 2.2.3. Mô hình dữ liệu hệ thống

```
+-------------------+       +-----------------------+       +-------------------+
|       User        |       |  UserSecurityProfile  |       |   FamilyCircle    |
+-------------------+       +-----------------------+       +-------------------+
| uid               | 1   1 | uid                   | 1   n | circleId          |
| email             |-------| publicKeyBase64       |-------| ownerId           |
| displayName       |       | sha256Fingerprint     |       | memberIds (list)  |
| photoUrl          |       | keystoreAlias         |       | isLocationShared  |
+-------------------+       | createdAt             |       +-------------------+
                            +-----------------------+                 | 1
                                                                      |
                                                                      | n
+-----------------------+       +-----------------------+   +-------------------+
|      AuditLog         |       |       SosEvent        |   |   LocationPing    |
+-----------------------+       +-----------------------+   +-------------------+
| logId                 |       | sosId                 |   | pingId            |
| title                 |       | senderId              |   | senderId          |
| description           |       | encryptedPayload      |   | encryptedPayload  |
| timestamp             |       | isMockGps             |   | timestamp         |
| isSecurityAlert       |       | status (ACTIVE/RESOLV)|   | nonce             |
+-----------------------+       +-----------------------+   +-------------------+
```

---

## 2.3. Mô hình phân tích đe dọa STRIDE chi tiết

Mô hình STRIDE được áp dụng để đánh giá có hệ thống mọi khía cạnh an ninh của hệ thống:

| Mối đe dọa (STRIDE) | Kịch bản tấn công cụ thể | Hậu quả tiềm tàng | Cơ chế phòng thủ kỹ thuật trong Đồ án | Test kiểm chứng thực tế |
|---|---|---|---|---|
| **S** - Spoofing (Giả mạo danh tính) | Kẻ tấn công giả danh máy chủ Firebase hoặc gửi Public Key giả để tráo đổi phiên liên lạc. | Lộ tọa độ vị trí cho kẻ trung gian độc hại. | Xác thực tài khoản qua Google Sign-In; đối chiếu mã vân tay an toàn **SHA-256 Key Fingerprint** ngoài băng. | `auth_key_provisioning_test.dart` |
| **T** - Tampering (Can thiệp sửa đổi) | Kẻ xấu sửa 1 bit dữ liệu vị trí trên đường truyền (bit-flipping) hoặc thay đổi trạng thái SOS. | Nạn nhân bị báo sai tọa độ cứu hộ sang địa điểm khác. | Mã hóa xác thực **AES-256-GCM** với Authentication Tag 128-bit. Mọi sửa đổi đều bị từ chối giải mã ngay lập tức. | `security_attack_suite_test.dart` (ATK-02) |
| **R** - Repudiation (Chối bỏ trách nhiệm) | Kẻ phát tín hiệu SOS giả chối bỏ hành vi; người dùng phủ nhận việc đã tra cứu vị trí người khác. | Mất niềm tin trong gia đình, không thể truy vết sự cố. | Hệ thống **Nhật ký kiểm toán minh bạch (AuditLog)** ghi vết thời gian, UID và hành động với trạng thái bảo vệ cục bộ. | `widget_test.dart` & `app_state_test.dart` |
| **I** - Information Disclosure (Tiết lộ thông tin) | Kẻ nghe lén bắt trộm gói tin trên đường truyền Wi-Fi hoặc trích xuất database đám mây. | Lộ toàn bộ lịch sử di chuyển, địa chỉ nhà, thói quen sống. | **Mã hóa đầu cuối (E2EE)** X25519 + AES-256-GCM; Private Key niêm phong trong **Android Keystore**. Plaintext rò rỉ = **0 byte**. | `security_attack_suite_test.dart` (ATK-01) |
| **D** - Denial of Service (Từ chối dịch vụ) | Kẻ tấn công ghi lại gói tin SOS cũ và liên tục phát lại (Replay Attack) làm nghẽn hệ thống và gây hoang mang. | Đội cứu hộ kiệt sức vì báo động giả liên tục. | Bộ phòng ngự **ReplayGuard**: Ghi nhận Nonce duy nhất (từ chối trước giải mã) + Kiểm tra hạn sống TTL 30 phút. | `security_attack_suite_test.dart` (ATK-03 & ATK-03b) |
| **E** - Elevation of Privilege (Nâng đặc quyền) | Ứng dụng gián điệp cài trên máy chụp màn hình Recent Apps hoặc máy bị Root can thiệp sâu vào RAM. | Chiếm đoạt khóa phiên hoặc chụp trộm dữ liệu nhạy cảm. | Kích hoạt cờ **`FLAG_SECURE`** chống chụp màn hình; Cơ chế **Root Detection** hạ cờ tin cậy `isTrusted = false`. | `emergency_bypass_test.dart` & Native Kotlin |

---

## 2.4. Giao thức mật mã và Quy trình vận hành

### 2.4.1. Giao thức Thỏa thuận khóa và Pipeline Key Provisioning (Milestone 8)

```
[ Thiết bị Người dùng A ]                [ Cloud Firestore ]               [ Thiết bị Người dùng B ]
           |                                     |                                     |
    (Google Sign-In)                             |                              (Google Sign-In)
           |                                     |                                     |
Sinh cặp khóa X25519                             |                             Sinh cặp khóa X25519
Niêm phong Private Key A                         |                             Niêm phong Private Key B
vào Android Keystore                             |                             vào Android Keystore
           |                                     |                                     |
           |----- Public Key A (Base64) -------->|                                     |
           |      users/uid_A                    |<-------- Public Key B (Base64) -----|
           |                                     |          users/uid_B                |
           |<---- Tải về Public Key B -----------|                                     |
           |------------------------------------>|----- Chuyển tiếp Public Key A ----->|
           |                                     |                                     |
  Tính SharedSecret A =                          |                            Tính SharedSecret B =
  X25519(PrivA, PubB)                            |                            X25519(PrivB, PubA)
           |                                     |                                     |
           +----------------- CÙNG RÚT RA MỘT KHÓA PHIÊN AES-256 ----------------------+
           |                                                                           |
           v                                                                           v
  Đối chiếu SHA-256 Fingerprint <-------------------------------------------> Đối chiếu SHA-256 Fingerprint
  (Xác minh ngoài băng OOB)                                                   (Xác minh ngoài băng OOB)
```

### 2.4.2. Định dạng Gói tin Vận chuyển Mã hóa E2EE

Mọi loại dữ liệu nhạy cảm truyền tải trong hệ thống (tọa độ GPS, gói tin SOS, tin nhắn chat, âm thanh đính kèm) đều được đóng gói theo định dạng nhị phân chuẩn hóa, không phụ thuộc vào cấu trúc JSON của bên thứ ba:

$$\text{Transport Payload} = \text{Nonce (12 bytes)} \parallel \text{MAC Tag (16 bytes)} \parallel \text{Ciphertext (N bytes)}$$

Chuỗi byte này được mã hóa Base64 trước khi đẩy lên Firebase Firestore. Cấu trúc này đảm bảo tính tương thích tuyệt đối giữa các module và loại bỏ hoàn toàn metadata không cần thiết.

### 2.4.3. Cơ chế Chống phát lại Hai tầng (ReplayGuard)

`ReplayGuard` (`lib/data/services/replay_guard.dart`) hoạt động theo nguyên tắc thẩm định 2 tầng nghiêm ngặt:

```
                      Gói tin SOS đến
                            |
                            v
       [ TẦNG 1: Kiểm tra Nonce 96-bit trong Bộ nhớ ]
                            |
            +---------------+---------------+
            |                               |
       (Trùng Nonce)                   (Nonce Mới)
            |                               |
            v                               v
    TỪ CHỐI NGAY LẬP TỨC!            Tiến hành Giải mã AES-GCM
    (ReplayVerdict.duplicateNonce)          |
    (Không tốn CPU giải mã)                 v
                                    [ TẦNG 2: Kiểm tra Timestamp đã xác thực ]
                                            |
                            +---------------+---------------+
                            |                               |
                     (Quá hạn > 30p)                 (Còn hạn < 30p)
                            |                               |
                            v                               v
                    TỪ CHỐI GÓI TIN!                 CHẤP NHẬN GÓI TIN HỢP LỆ
                    (ReplayVerdict.expired)          (ReplayVerdict.accepted)
```

---

# CHƯƠNG 3 — KẾT QUẢ THỰC NGHIỆM VÀ ĐÁNH GIÁ CHẤT LƯỢNG

## 3.1. Thống kê quy mô và chất lượng mã nguồn dự án

Sau khi hoàn thiện trọn vẹn Milestone 8, dự án đạt quy mô và chất lượng kỹ thuật cao:

| Hạng mục thống kê | Định lượng thực tế | Ghi chú kỹ thuật |
|---|---|---|
| **Khung phát triển** | Flutter 3.x / Dart 3.13 | Tương thích đa nền tảng, biên dịch mã máy AOT |
| **Mã nguồn ứng dụng (`lib/`)** | **5.846 dòng Dart** (22 files) | Kiến trúc phân lớp sạch (Clean Architecture) |
| **Mã nguồn native Android** | **100 dòng Kotlin** (`MainActivity.kt`) | Quản lý `FLAG_SECURE` và Root Detection |
| **Mã nguồn kiểm thử (`test/`)** | **2.302 dòng Dart** (10 files) | Kiểm thử tấn công, benchmark, widget test |
| **Lớp dịch vụ (Services)** | **10 dịch vụ chuyên biệt** | `Crypto`, `Auth`, `Sos`, `Geofence`, `ReplayGuard`... |
| **Màn hình giao diện (Screens)** | **8 màn hình hoàn chỉnh** | `Map`, `SosCountdown`, `Circle`, `Chat`, `Profile`... |
| **Kết quả kiểm thử tự động** | **100/100 tests PASS (100%)** | Chạy qua lệnh `flutter test`, exit code 0 |
| **Chất lượng mã nguồn Linter** | **0 Issue** (0 error, 0 warning, 0 info) | Tuân thủ bộ quy tắc nghiêm ngặt `flutter_lints` 6.0 |
| **Kết quả Build ứng dụng** | **BUILD SUCCESSFUL** | Tạo gói APK debug dung lượng 187MB |

---

## 3.2. Đánh giá hiệu năng mật mã (Crypto Benchmark)

Hiệu năng của các phép toán mật mã được đo lường thực nghiệm thông qua bài kiểm tra `test/crypto_benchmark_test.dart` với **300 vòng lặp** liên tục cho mỗi thuật toán, có giai đoạn warm-up để loại bỏ độ trễ khởi tạo JIT:

| Phép toán mật mã | Thời gian trung bình (ms) | Tổng 300 lần chạy (ms) | Thông lượng (ops/giây) | Ngưỡng yêu cầu đồ án | Kết luận |
|---|---|---|---|---|---|
| **ECDH X25519 (`deriveSharedKey`)** | **0,78 ms** | 233,56 ms | 1.284 | < 10,0 ms | **Đạt xuất sắc** |
| **AES-256-GCM Encrypt (Vị trí SOS)** | **0,12 ms** | 37,87 ms | 7.922 | < 10,0 ms | **Đạt xuất sắc** |
| **AES-256-GCM Decrypt (Vị trí SOS)** | **0,11 ms** | 34,79 ms | 8.624 | < 10,0 ms | **Đạt xuất sắc** |
| **SHA-256 (Mã chia sẻ hành trình)** | **0,03 ms** | 11,88 ms | 25.263 | < 10,0 ms | **Đạt xuất sắc** |
| **AES-256-GCM Decrypt (Chat E2EE)** | **0,04 ms** | 11,34 ms | 26.455 | < 10,0 ms | **Đạt xuất sắc** |

**Phân tích định lượng chuyên sâu:**
1. **Thuật toán đối xứng đạt tốc độ siêu việt:** Mã hóa và giải mã AES-256-GCM chỉ tiêu tốn trung bình từ **0,04 ms đến 0,12 ms**, tương ứng với thông lượng xử lý hơn 8.000 phép tính mỗi giây. Trong bối cảnh chu kỳ cập nhật tọa độ GPS định kỳ là 10.000 ms (10 giây), chi phí tính toán của thuật toán mã hóa chỉ chiếm **0,0012%** thời gian của chu kỳ, hoàn toàn không gây ảnh hưởng đến hiệu năng CPU cũng như thời lượng pin của thiết bị.
2. **Chi phí trao đổi khóa bất đối xứng hợp lý:** Phép nhân điểm trên đường cong Montgomery Curve25519 tiêu tốn 0,78 ms, chậm hơn AES-GCM khoảng 7 lần do bản chất toán học đường cong phức tạp. Tuy nhiên, thao tác này chỉ diễn ra **duy nhất một lần** trong phiên thiết lập liên lạc ban đầu. Kết quả 0,78 ms nhanh hơn gấp 12 lần so với ngưỡng trần 10 ms mà đề cương đặt ra, khẳng định tính khả thi vượt trội khi triển khai trên thiết bị di động.

---

## 3.3. Kết quả thực nghiệm 5 kịch bản tấn công bảo mật

Bộ kiểm thử tấn công tự động `test/security_attack_suite_test.dart` và `test/auth_key_provisioning_test.dart` đã thực nghiệm 5 kịch bản thâm nhập thực tế:

### 3.3.1. ATK-01: Tấn công Nghe lén và Bắt gói tin (Eavesdropping / Sniffing)
- **Phương thức:** Giả lập kẻ tấn công bắt trộm gói tin vị trí `EncryptedSosPayload` và tin nhắn `ChatMessage` khi chúng truyền tải qua Cloud Firestore. Tiến hành quét tìm chuỗi văn bản rõ các thông số nhạy cảm: tọa độ vĩ độ (`21.0285`), kinh độ (`105.8542`), mã `sosId`, nội dung chat (`951122`).
- **Kết quả thực nghiệm:** Tỷ lệ rò rỉ văn bản rõ = **0 byte**. Mọi trường dữ liệu nhạy cảm đều đã được biến đổi thành chuỗi Base64 ngẫu nhiên.
- **Thử nghiệm giải mã trái phép:** Kẻ tấn công sử dụng cặp khóa ECDH hợp lệ của chính hắn để giải mã gói tin đánh cắp. Hệ thống ném ra biệt lệ từ chối giải mã do không sở hữu shared secret tương thích.

### 3.3.2. ATK-02: Tấn công Sửa đổi dữ liệu và Đảo bit (Tampering / Bit-flipping)
- **Phương thức:** Kẻ tấn công can thiệp vào đường truyền, cố tình làm thay đổi 1 bit ngẫu nhiên trong bản mã Ciphertext, đổi 1 bit trong MAC Tag 128-bit, hoặc thay thế Nonce bằng Nonce của một gói tin khác.
- **Kết quả thực nghiệm:** 100% các gói tin bị sửa đổi đều bị thuật toán AES-GCM phát hiện và từ chối xử lý, ném ngoại lệ `SecretBoxAuthenticationError`. Không có bất kỳ gói tin sai lệch nào lọt qua tầng bảo vệ mật mã.

### 3.3.3. ATK-03: Tấn công Phát lại gói tin SOS (Replay Attack)
- **Phương thức:** Ghi lại một gói tin cứu hộ SOS hợp lệ, sau đó liên tục gửi lại máy chủ sau 5 phút, 15 phút và 35 phút nhằm kích động báo động giả.
- **Kết quả thực nghiệm:**
  - Lần phát lại 1 (cùng Nonce): Bị tầng 1 của `ReplayGuard` phát hiện và từ chối với lý do `ReplayVerdict.duplicateNonce`.
  - Gói tin giả mạo timestamp gửi sau 35 phút: Bị tầng 2 phát hiện quá hạn sống và từ chối với lý do `ReplayVerdict.expired`.
  - Luồng cảnh báo cứu hộ không bị kích hoạt giả mạo; đồng thời sự kiện tấn công lập tức được ghi vào `AuditLog` để cảnh báo người dùng.

### 3.3.4. ATK-04: Tấn công Giả mạo vị trí GPS (Mock GPS Spoofing)
- **Phương thức:** Kích hoạt tùy chọn nhà phát triển trên thiết bị Android, sử dụng phần mềm bên thứ ba để phát tọa độ GPS giả lập (bật cờ `Position.isMocked = true`).
- **Kết quả thực nghiệm:** `TamperDetector.isMockLocation` phát hiện chính xác trạng thái giả lập. Trạng thái toàn vẹn của ứng dụng chuyển thành `isTrusted = false`, giao diện `SecurityScreen` lập tức hiển thị thẻ cảnh báo nguy hiểm màu đỏ: *"Phát hiện GPS giả lập"*.

### 3.3.5. ATK-05: Tấn công Chiếm đoạt khóa và Kẻ đứng giữa (Key Hijacking / MITM)
- **Phương thức:** Giả lập trường hợp kẻ tấn công cố tình thay thế Public Key của nạn nhân trên cơ sở dữ liệu Firebase bằng Public Key của hắn nhằm giải mã các liên lạc sau này.
- **Kết quả thực nghiệm:** Khi người dùng kiểm tra mục *Chứng chỉ Khóa Mật mã Keystore* trên màn hình `ProfileScreen`, mã vân tay **SHA-256 Key Fingerprint** hiển thị sai lệch hoàn toàn so với mã vân tay gốc của người thân. Cuộc tấn công bị phát hiện ngay lập tức qua đối chiếu ngoài băng. Private Key gốc của người dùng được bảo vệ an toàn tuyệt đối bên trong Android Keystore, kẻ tấn công không có cách nào trích xuất được.

---

## 3.4. Bảng danh mục chi tiết 100 Test Cases

Bộ kiểm thử gồm 10 tập tin kiểm thử tự động, bao phủ 100% các chức năng nghiệp vụ và an toàn bảo mật:

| Tập tin kiểm thử | Số lượng test | Phạm vi và Nội dung kiểm thử |
|---|---|---|
| `test/geofence_test.dart` | **23 tests** | Kiểm tra công thức Haversine, độ trôi kinh vĩ tuyến, trạng thái vào/ra ranh giới vùng an toàn 100m. |
| `test/sos_test.dart` | **22 tests** | Đóng gói payload SOS, vòng đời ACTIVE → RESOLVED, tích hợp quy trình nhận `handleIncomingSos`. |
| `test/security_attack_suite_test.dart` | **18 tests** | Bộ kiểm thử tấn công ATK-01 (nghe lén), ATK-02 (bit-flipping), ATK-03 (replay), ATK-04 (mock GPS). |
| `test/chat_e2ee_test.dart` | **9 tests** | Kiểm tra chu trình gửi/nhận tin nhắn chat E2EE, mã hóa tệp tin nhị phân, kiểm tra rò rỉ bản rõ. |
| `test/trip_share_test.dart` | **7 tests** | Sinh mã 6 số CSPRNG, băm an toàn SHA-256, kiểm tra thời hạn sống TTL và xác thực mã. |
| `test/widget_test.dart` | **6 tests** | Luồng điều hướng UI, tương tác nút SOS nhấn giữ 2s, đếm ngược 3s và hủy bỏ khẩn cấp. |
| `test/emergency_bypass_test.dart` | **5 tests** | Kiểm chứng nguyên lý Zero Barrier, hàng rào sinh trắc học Scoped Gate, cờ native `FLAG_SECURE`. |
| `test/crypto_service_test.dart` | **4 tests** | Trao đổi khóa ECDH X25519, tính ngẫu nhiên của Nonce, bắt lỗi xác thực bản mã bị can thiệp. |
| `test/auth_key_provisioning_test.dart` | **4 tests** | Tự động sinh khóa Keystore (M8), tính Idempotent khi đăng nhập lại, ECDH giữa 2 user, thu hồi khóa. |
| `test/crypto_benchmark_test.dart` | **2 tests** | Đo đạc hiệu năng 300 vòng lặp cho ECDH, AES-GCM mã hóa/giải mã và SHA-256. |
| **TỔNG CỘNG** | **100 tests** | **100/100 tests PASS tuyệt đối (100% tỷ lệ thành công)** |

---

## 3.5. Đối chiếu kết quả với Tiêu chí đánh giá của Đề cương

| Tiêu chí đánh giá (Mục 7.2) | Yêu cầu chuẩn | Kết quả thực tế đạt được | Đánh giá |
|---|---|---|---|
| **1. Tính đúng đắn** | Ứng dụng đáp ứng đúng các chức năng đã đăng ký, không lỗi chặn luồng chính. | Triển khai hoàn chỉnh 8/8 module chức năng; 100/100 tests PASS; `flutter analyze` sạch 0 issue. | **Xuất sắc** |
| **2. Tính bảo mật** | Mỗi cơ chế có threat model, được kiểm thử bằng tấn công thực tế và ghi nhận kết quả. | Xây dựng ma trận STRIDE toàn diện; 5 kịch bản tấn công thực nghiệm; tích hợp Keystore & ReplayGuard. | **Xuất sắc** |
| **3. Tính khả thi & Triển khai** | Chạy ổn định trên thiết bị thật, không phụ thuộc môi trường giả lập riêng. | Đã cấu hình Firebase Auth & Google Sign-In thật, SHA-1 Keystore thật; Build APK thành công 100%. | **Xuất sắc** |
| **4. Chất lượng học thuật** | Báo cáo khoa học, cấu trúc chặt chẽ, số liệu thực nghiệm đo đạc chính xác. | Báo cáo đầy đủ 4 chương, chuẩn mẫu KMA, có bảng benchmark 300 lần chạy, trích dẫn học thuật IEEE. | **Xuất sắc** |

---

# CHƯƠNG 4 — KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN

## 4.1. Kết quả đạt được của đồ án

Sau quá trình nghiên cứu lý thuyết chuyên sâu và lập trình thực nghiệm bài bản, đồ án đã hoàn thành xuất sắc toàn bộ các mục tiêu đặt ra trong đề cương:

1. **Hiện thực hóa trọn vẹn mô hình "Server Zero-Knowledge":** Xây dựng thành công ứng dụng di động bảo vệ gia đình mà ở đó máy chủ đám mây chỉ đóng vai trò là kênh chuyển tiếp (blind relay), hoàn toàn không có khả năng đọc được dữ liệu tọa độ, nội dung cầu cứu hay tin nhắn của người dùng.
2. **Làm chủ và tích hợp nhuần nhuyễn các công nghệ mật mã hiện đại:** Kết hợp hài hòa giữa trao đổi khóa đường cong Elliptic X25519, hàm rút khóa HKDF-SHA256, và mã hóa xác thực AES-256-GCM, giải quyết triệt để các lỗi kỹ thuật phần cứng đặc thù trên Android (lỗi JCE Empty Salt).
3. **Nâng tầm bảo mật với phần cứng Android Keystore (Milestone 8):** Đưa khóa bí mật vào lưu trữ trong phần cứng an toàn TEE/StrongBox, kết hợp xác thực ngoài băng qua mã vân tay an toàn SHA-256 Fingerprint, giải quyết triệt để nguy cơ tấn công kẻ đứng giữa (MITM).
4. **Đột phá về trải nghiệm người dùng với kiến trúc Emergency Bypass:** Chứng minh tính đúng đắn của nguyên tắc *Zero Barrier* trong cứu hộ khẩn cấp — mở app là cứu được ngay mà không phải chờ đợi vượt qua các hàng rào xác thực phức tạp, trong khi vẫn bảo vệ an toàn dữ liệu nhạy cảm bằng *Scoped Biometrics*.
5. **Đạt độ tin cậy phần mềm tuyệt đối:** Toàn bộ hệ thống được bảo chứng bởi bộ kiểm thử 100/100 tests tự động, phân tích mã nguồn không có bất kỳ lỗi hay cảnh báo nào, tốc độ xử lý mật mã dưới 1 ms.

## 4.2. Bài học kinh nghiệm thực tiễn

1. **Tư duy thiết kế "Kẻ tấn công ở đâu?":** An toàn thông tin không phải là việc đính kèm các thư viện mật mã vào dự án một cách thụ động, mà phải bắt đầu từ việc mô hình hóa đe dọa (Threat Modeling). Việc xây dựng kịch bản kiểm thử tấn công trước khi viết mã nguồn giúp phát hiện sớm các lỗ hổng kiến trúc nghiêm trọng (như lỗ hổng Replay Attack từng được phát hiện ở M6 và khắc phục ở M7).
2. **Hiểu rõ hệ sinh thái triển khai nền tảng:** Mật mã học trên lý thuyết và mật mã học trên thiết bị di động thực tế có khoảng cách lớn. Lỗi `InvalidKeyException` của Android JCE đối với HKDF empty salt là minh chứng sống động cho thấy lập trình viên ATBM phải nắm vững cả kiến trúc hệ điều hành lẫn tiêu chuẩn toán học RFC.
3. **Sự minh bạch trong bảo mật:** Tính năng *AuditLog* và *Mã vân tay SHA-256* cho thấy một nguyên lý quan trọng: Hệ thống bảo mật tốt nhất là hệ thống cung cấp cho người dùng công cụ để tự kiểm chứng tính an toàn của chính mình.

## 4.3. Các hạn chế còn tồn tại

Dù đã đạt được những bước tiến dài về mặt công nghệ, hệ thống vẫn còn một số điểm giới hạn cần được ghi nhận trung thực:
- **Phụ thuộc vào kết nối Internet:** Luồng truyền thông hiện tại phụ thuộc vào hạ tầng mạng di động 4G/Wi-Fi và dịch vụ đám mây Firebase. Khi đi vào các vùng mất sóng, hầm sâu hoặc bị phá sóng chủ động, cảnh báo chưa thể truyền đi tức thì.
- **Phát hiện GPS giả lập dựa trên cờ hệ điều hành:** Cơ chế hiện tại phụ thuộc vào cờ `isMocked` của Android. Một số công cụ root can thiệp sâu vào kernel có thể ẩn cờ này. Ứng dụng cần bổ sung thuật toán phân tích gia tốc và độ trôi vị trí bất thường để bù đắp.
- **Hạn chế xác thực tự động danh tính:** Việc đối chiếu SHA-256 Fingerprint hiện tại vẫn đòi hỏi thao tác thủ công của người dùng (gặp mặt hoặc đọc qua điện thoại), chưa tích hợp chữ ký số công khai Ed25519 tự động qua hạ tầng CA nội bộ gia đình.

## 4.4. Hướng phát triển trong tương lai

1. **Mạng cứu hộ Mesh ngoại tuyến (Offline Mesh Network qua Bluetooth LE / Wi-Fi Direct):** Xây dựng giao thức truyền tin đa bước (multi-hop peer-to-peer) giữa các điện thoại di động trong phạm vi gần khi mất kết nối Internet hoàn toàn, cho phép chuyển tiếp gói tin SOS mã hóa E2EE đến thiết bị có sóng gần nhất.
2. **Tích hợp Chữ ký số Ed25519:** Mở rộng cặp khóa X25519 hiện tại sang cặp khóa ký Ed25519, biến thiết bị của chủ gia đình (Owner) thành một Root CA nội bộ ký chứng thực khóa cho các thành viên, loại bỏ hoàn toàn nhu cầu đối chiếu vân tay thủ công.
3. **Mã hóa cơ sở dữ liệu cục bộ bằng SQLCipher:** Nâng cấp tầng lưu trữ SQLite nội bộ bằng SQLCipher với khóa dẫn xuất trực tiếp từ Android Keystore.
4. **Thuật toán Machine Learning phát hiện độ trôi GPS:** Ứng dụng mô hình lọc Kalman và thuật toán phát hiện bất thường để nhận diện hành vi giả lập tọa độ GPS dựa trên quán tính di chuyển thực tế.

---

# TÀI LIỆU THAM KHẢO

1. **NIST Special Publication 800-207**, *Zero Trust Architecture*, National Institute of Standards and Technology, U.S. Department of Commerce, 2020.
2. **RFC 7748**, *Elliptic Curves for Security: Curve25519 and Curve448*, Internet Engineering Task Force (IETF), 2016.
3. **RFC 5869**, *HMAC-based Extract-and-Expand Key Derivation Function (HKDF)*, IETF, 2010.
4. **NIST FIPS PUB 197**, *Advanced Encryption Standard (AES)*, Federal Information Processing Standards Publication, 2001.
5. **NIST Special Publication 800-38D**, *Recommendation for Block Cipher Modes of Operation: Galois/Counter Mode (GCM) and GMAC*, 2007.
6. **NIST FIPS PUB 180-4**, *Secure Hash Standard (SHS)*, 2015.
7. **OWASP Foundation**, *Mobile Application Security Verification Standard (MASVS) Version 2.0*, 2024.
8. **OWASP Foundation**, *OWASP Top 10 Mobile Risks*, 2024.
9. **Microsoft Corporation**, *The STRIDE Threat Model*, Microsoft Security Development Lifecycle, 2024.
10. **Google Developers**, *Android Keystore System & Hardware-backed security*, Android Open Source Project (AOSP) Documentation, 2024.
11. **Google Developers**, *WindowManager.LayoutParams.FLAG_SECURE*, Android API Reference, 2024.
12. **Signal Messenger LLC**, *The Double Ratchet Algorithm & X25519 Protocol Specification*, 2023.
13. **Daniel J. Bernstein**, *Curve25519: high-speed elliptic-curve cryptography*, Public Key Cryptography - PKC 2006, Lecture Notes in Computer Science, Springer, 2006.
14. **Học viện Kỹ thuật Mật mã**, *Giáo trình Cơ sở Mật mã học và An toàn Hệ thống Thông tin*, NXB Quân đội Nhân dân, 2022.
15. **Thư viện Cryptography Dart**, *Cryptography in Dart & Flutter using libsodium and platform APIs*, pub.dev/packages/cryptography, 2024.
16. **Flutter Open Source Project**, *Flutter Architectural Overview & Platform Channels*, flutter.dev/docs, 2024.

---

# PHỤ LỤC: TỔNG HỢP CÁC CƠ CHẾ BẢO MẬT ĐÃ TRIỂN KHAI

| STT | Cơ chế bảo mật | Công nghệ / Thuật toán | Vị trí hiện thực | Test case kiểm chứng | Hiệu quả thực nghiệm |
|---|---|---|---|---|---|
| **1** | Thỏa thuận khóa phiên | ECDH X25519 + HKDF-SHA256 | `crypto_service.dart` | `crypto_service_test.dart` | Tốc độ 0,78 ms, miễn nhiễm timing attack |
| **2** | Mã hóa đầu cuối (E2EE) | AES-256-GCM (Tag 128-bit) | `crypto_service.dart`, `sos_service.dart` | `sos_test.dart`, `chat_e2ee_test.dart` | 0 byte plaintext rò rỉ, phát hiện đảo 1 bit |
| **3** | Lưu trữ khóa phần cứng | Android Keystore (TEE/StrongBox) | `secure_storage_service.dart`, `auth_service.dart` | `auth_key_provisioning_test.dart` | Private key không thể trích xuất ra ngoài |
| **4** | Xác thực ngoài băng | SHA-256 Key Fingerprinting | `crypto_service.dart`, `auth_service.dart` | `auth_key_provisioning_test.dart` | Triệt tiêu tấn công kẻ đứng giữa (MITM) |
| **5** | Phòng chống phát lại | ReplayGuard (Nonce + TTL 30p) | `replay_guard.dart`, `sos_service.dart` | `security_attack_suite_test.dart` (ATK-03) | Nonce trùng từ chối trước giải mã |
| **6** | Kiến trúc cứu nạn khẩn cấp | Emergency Bypass (Zero Barrier) | `main.dart`, `sos_countdown_screen.dart` | `emergency_bypass_test.dart` | Cứu hộ không rào cản trong 2 giây |
| **7** | Bảo vệ vùng nhạy cảm | Scoped Biometrics (`local_auth`) | `biometric_service.dart`, `main.dart` | `emergency_bypass_test.dart` | Khóa vân tay các tab riêng tư |
| **8** | Chống chụp trộm màn hình | Native `FLAG_SECURE` | `MainActivity.kt`, `native_security_service.dart` | `emergency_bypass_test.dart` | Chặn screenshot, che mờ Recent Apps |
| **9** | Phát hiện xâm phạm thiết bị | Root Detection (`su` & test-keys) | `MainActivity.kt`, `native_security_service.dart` | `security_attack_suite_test.dart` (ATK-04) | Cảnh báo đỏ khi máy bị root |
| **10** | Chống giả mạo GPS | Mock Location Detection | `tamper_detector.dart`, `app_state.dart` | `security_attack_suite_test.dart` (ATK-04) | Nhận diện GPS giả, ghi vết kiểm toán |
| **11** | Chia sẻ hành trình an toàn | CSPRNG 6 số + SHA-256 + TTL | `trip_share_service.dart` | `trip_share_test.dart` | Mã dùng 1 lần, hết hạn tự động hủy |
| **12** | Minh bạch hóa dữ liệu | Audit Logging | `app_state.dart`, `audit_log_screen.dart` | `widget_test.dart` | Người dùng kiểm tra được ai đã xem vị trí |

---
*— HẾT BÁO CÁO —*
