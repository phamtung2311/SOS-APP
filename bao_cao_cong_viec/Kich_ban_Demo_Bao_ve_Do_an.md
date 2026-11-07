# KỊCH BẢN DEMO BẢO VỆ ĐỒ ÁN — SOS & An toàn Gia đình

**Thời lượng: 3 phút (180 giây).**
**Thiết bị: 2 máy Android (máy gửi + máy nhận), hoặc 1 máy thật + emulator `Medium_Phone`.**
**Cố định trước khi demo (bắt buộc):**
- [ ] 2 thiết bị cùng đăng nhập vào **một vòng tròn gia đình** (Circle)
- [ ] Cả 2 thiết bị bật **bản đồ OSM** đang hiển thị
- [ ] Mở sẵn tab **Firestore console** trên máy chiếu (bằng chứng E2EE)
- [ ] Mở sẵn tab **Crypto Inspector** trong app (bằng chứng ciphertext)

---

## MỞ ĐẦU (0:00 – 0:15)

> *"Em xin demo trực tiếp trên 2 thiết bị thật. Hai thiết bị đã cùng một vòng tròn gia đình, cùng một phiên E2EE. Em sẽ làm 4 việc: (1) bấm SOS, (2) mở vùng nhạy cảm đòi vân tay, (3) chia sẻ hành trình 6 số, và (4) cho thầy cô xem ciphertext thực tế."*

---

## CẢNH 1 — NÚT SOS KHẨN CẤP (0:15 – 0:45)

**Thao tác trên máy gửi (Thiết bị A):**

1. Từ màn bản đồ, **giữ nút SOS đỏ 2 giây** (trên bản đồ, góc dưới bên phải).
2. Màn hình đếm ngược **3 → 2 → 1** hiện ra. Nếu không khẩn cấp, có nút **HỦY**.
3. Đợi đếm xong → **cảnh báo SOS được gửi** (báo động trên thiết bị A).

**Thao tác trên máy nhận (Thiết bị B):**

4. Ngay lập tức, **banner khẩn cấp đỏ** hiện trên bản đồ của thiết bị B:
   *"Nhận cảnh báo SOS từ [Tên A] — đã giải mã E2EE."*
5. Bản đồ tự **di chuyển tới tọa độ khẩn cấp** (đã mã hóa, chỉ bên nhận mới giải mã được).

**Narration:**
> *"Đây là Zero Barrier — em không cần đăng nhập, không cần vân tay. Cứu mạng không chờ sinh trắc học. Trên thiết bị nhận, chú ý: tọa độ được hiện ra **sau khi giải mã E2EE**, không phải từ plaintext trên server."*

**Điểm nhấn:** Nhấn giữ 2 giây là có cảnh báo — **≤ 2 giây**.

---

## CẢNH 2 — SCOPED GATE / SINH TRẮC HỌC (0:45 – 1:15)

**Thao tác trên máy gửi (Thiết bị A):**

6. Rút đáy lên, bấm **tab "Vòng tròn"** (hoặc tab "Nhật ký"/tab "Cài đặt bảo mật").
7. **Yêu cầu vân tay / Face ID** (Biometric Prompt) hiện ra — vùng dữ liệu nhạy cảm bị khóa.
8. Bấm vân tay → được vào.

**Narration:**
> *"Đây là Scoped Gate. Bản đồ và nút SOS thì ai cũng vào được, nhưng vùng dữ liệu nhạy cảm — vòng tròn, chat E2EE, nhật ký di chuyển, cài đặt — được bảo vệ bằng sinh trắc học. Bảo mật được đặt đúng chỗ: chặn người lạ, không chặn người gặp nguy hiểm."*

---

## CẢNH 3 — CHIA SẺ HÀNH TRÌNH MÃ 6 SỐ (1:15 – 1:45)

**Thao tác:**

9. Bật tính năng **Chia sẻ hành trình** (trên bản đồ, mục "Báo cáo an toàn").
10. App sinh **mã 6 chữ số** (CSPRNG `Random.secure()`) và hiển thị cho người dùng **một lần duy nhất**.
11. Người đi đường (taxi) nhập mã 6 số đó để theo dõi vị trí trong **60 phút** (TTL).

**Narration:**
> *"Mã chia sẻ dùng một lần, có hạn. Em không lưu mã gốc lên server — chỉ lưu **SHA-256 của mã**. Nếu server bị lộ, hacker cũng chỉ thấy chuỗi băm, không thấy mã. Sau 60 phút mã tự hủy."*

---

## CẢNH 4 — BẰNG CHỨNG E2EE (cường độ demo quan trọng nhất) (1:45 – 2:30)

**Thao tác (máy chiếu):**

12. Mở **tab Firestore console** → collection `sosEvents` (hoặc `locations`).
13. **Chỉ cho hội đồng xem rõ**: toàn bộ trường `lat`/`lng`/`encryptedEvent` là **ciphertext base64 dài** — không đọc được.
14. Mở **Crypto Inspector** trong app → hiển thị từng trường: `ciphertext`, `nonce`, `mac` ở dạng base64 — chứng minh **3 thành phần AEAD**.

**Narration:**
> *"Đây là ảnh chụp quan trọng nhất của buổi bảo vệ. Thầy cô thấy trên Firestore: không có plaintext vị trí nào. Máy chủ chỉ là relay. Mật mã AES-256-GCM với nonce và MAC được gửi, server không giải mã được. Đây là điểm khác biệt so với các đồ án khác chỉ có JWT và băm mật khẩu."*

---

## KẾT THÚC DEMO & SỬA SAI (2:30 – 3:00)

> *"Demo kết thúc. Em đã chứng minh được 3 điều: (1) SOS hoạt động trong 2 giây không rào cản, (2) vùng nhạy cảm có sinh trắc học, (3) máy chủ không đọc được dữ liệu. Cảm ơn thầy cô."*

**Backup khi mất kết nối / demo lỗi:**

| Sự cố | Xử lý |
|---|---|
| Mất mạng giữa demo | Chạy lại bằng 2 máy emulator, nhấn **Mở lại** kết nối |
| Vân tay không đọc được | Bấm **Xác thực bằng mã PIN dự phòng** (fallback của `BiometricGate`) |
| Firestore không thấy dữ liệu | Mở màn hình **Crypto Inspector** trong app (dữ liệu đã có sẵn), nói rõ "em đang demo offline" |
| GPS mock không bật được | Nói rõ: *"cảnh này cần mock GPS từ Developer Options, em có sẵn ảnh chụp màn hình"*, mở ảnh dự phòng trong thư mục `docs/anh-chup/` |

---

## BẰNG CHỨNG CẦN CHUẨN BỊ SẴN (bắt buộc cho buổi bảo vệ)

1. **Ảnh chụp màn hình** (tạo sẵn trong `docs/anh-chup/`):
   - [ ] Ciphertext trên Firestore console (mục 5.4 đề cương — ảnh quan trọng nhất)
   - [ ] Ciphertext trong Crypto Inspector của app
   - [ ] Banner khẩn cấp SOS hiện trên máy nhận
   - [ ] Biometric Prompt (yêu cầu vân tay)
   - [ ] Mã chia sẻ hành trình 6 số hiển thị
   - [ ] Cảnh báo "GPS giả lập" trên thẻ TamperReport
   - [ ] Cảnh báo tấn công replay trong nhật ký kiểm toán (M7)

2. **Video quay màn hình demo 3 phút** (lưu trong `docs/bao-cao/`) — để backup khi demo trực tiếp bị sự cố.

---

## CÂU HỎI DỰ KIẾN & CÁCH TRẢ LỜI NGẮN

| Câu hỏi | Trả lời |
|---|---|
| *Server có đọc được vị trí không?* | Không — chỉ ciphertext. Demo Firestore console chứng minh. |
| *Không có mạng thì SOS có hoạt động không?* | Chưa — là hạn chế đã nêu. Hướng M8: Mesh BLE/Wi-Fi Direct. |
| *Có chữ ký không, MITM thì sao?* | Chưa — chữ ký Ed25519 là hạng mục ưu tiên cao M8. |
| *Số liệu < 1ms đo bằng gì?* | `flutter test` headless, 300 vòng, có warm-up; bảng benchmark ở `crypto_benchmark_test.dart`. |
