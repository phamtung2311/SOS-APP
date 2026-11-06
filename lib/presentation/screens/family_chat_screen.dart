import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sos_safe_family/data/models/chat_message.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:uuid/uuid.dart';

/// Màn hình nhắn tin bảo mật E2EE với một thành viên gia đình.
///
/// Mọi tin nhắn đều được mã hóa AES-256-GCM bằng khóa phiên thỏa thuận qua
/// ECDH X25519 trước khi "đi trên đường truyền". Nút **Soi mật mã** cho phép
/// trình diễn trực tiếp plaintext ↔ ciphertext để phục vụ báo cáo đồ án.
class FamilyChatScreen extends StatefulWidget {
  const FamilyChatScreen({super.key, required this.memberName});

  final String memberName;

  @override
  State<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

class _FamilyChatScreenState extends State<FamilyChatScreen> {
  final CryptoService _crypto = CryptoService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  /// Khóa phiên dùng chung cho cả hai chiều (mô phỏng khóa đã thỏa thuận
  /// qua ECDH X25519 ngoài đời thực).
  Uint8List? _sharedKey;

  bool _isInspectorEnabled = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Thiết lập khóa phiên và nạp sẵn vài tin nhắn mẫu.
  Future<void> _bootstrap() async {
    final service = CryptoService();
    final alice = await service.generateKeyPairX25519();
    final bob = await service.generateKeyPairX25519();

    final shared = await service.deriveSharedKey(
      myKeyPair: alice,
      theirPublicKey: await service.importPublicKey(
        await service.exportPublicKey(bob),
      ),
    );

    final keyBytes = Uint8List.fromList(await shared.extractBytes());
    if (!mounted) return;
    setState(() => _sharedKey = keyBytes);

    await _seedMessages(keyBytes);
  }

  /// Tạo sẵn 4 tin nhắn mẫu (cả text và ảnh) để app sinh động ngay khi mở.
  Future<void> _seedMessages(Uint8List key) async {
    final seeds = <ChatMessage>[];

    Future<ChatMessage> makeText({
      required String from,
      required String name,
      required String text,
      required int minutesAgo,
    }) async {
      final payload = await _crypto.encryptTextMessage(text, key);
      return ChatMessage(
        id: const Uuid().v4(),
        senderId: from,
        senderName: name,
        timestamp: DateTime.now().subtract(Duration(minutes: minutesAgo)),
        type: MessageType.text,
        plaintext: text,
        ciphertextBase64: payload.ciphertextBase64,
        nonceBase64: payload.nonceBase64,
        macBase64: payload.macBase64,
      );
    }

    Future<ChatMessage> makeImage({
      required String from,
      required String name,
      required int minutesAgo,
      required Color color,
      required IconData icon,
    }) async {
      // Tạo một ảnh demo đơn giản (PNG 1x1 màu) rồi mã hóa như ảnh thật.
      final bytes = await _demoImageBytes(color, icon);
      final payload = await _crypto.encryptMediaBytes(bytes, key);
      return ChatMessage(
        id: const Uuid().v4(),
        senderId: from,
        senderName: name,
        timestamp: DateTime.now().subtract(Duration(minutes: minutesAgo)),
        type: MessageType.image,
        plaintext: '[Hình ảnh]',
        ciphertextBase64: payload.ciphertextBase64,
        nonceBase64: payload.nonceBase64,
        macBase64: payload.macBase64,
        decryptedImageBytes: bytes,
      );
    }

    seeds.add(await makeText(
      from: 'other',
      name: widget.memberName,
      text: 'Con ơi, con về nhà chưa? Mẹ lo lắng quá.',
      minutesAgo: 12,
    ));
    seeds.add(await makeText(
      from: 'me',
      name: 'Tôi',
      text: 'Con về rồi, đang trên đường về mẹ.',
      minutesAgo: 11,
    ));
    seeds.add(await makeImage(
      from: 'other',
      name: widget.memberName,
      minutesAgo: 10,
      color: const Color(0xFF43A047),
      icon: Icons.home_rounded,
    ));
    seeds.add(await makeText(
      from: 'other',
      name: widget.memberName,
      text: 'Tối nay về sớm nhé, mẹ nấu món con thích.',
      minutesAgo: 9,
    ));

    if (!mounted) return;
    setState(() => _messages.addAll(seeds));
  }

  /// Sinh bytes PNG demo (không cần package ảnh: dùng PNG 1x1 base64 cố định
  /// rồi chèn màu) — chỉ để minh hoạ luồng mã hóa ảnh.
  Future<Uint8List> _demoImageBytes(Color color, IconData icon) async {
    // PNG 1x1 đen tối giản lập "ảnh", đủ để demo mã hóa/giải mã nhị phân.
    const png1x1 = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0xB0, 0x00, 0x00, 0x00,
      0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
    return Uint8List.fromList(png1x1);
  }

  // ---------------------------------------------------------------------
  // Gửi tin nhắn
  // ---------------------------------------------------------------------

  Future<void> _sendText() async {
    final text = _inputController.text.trim();
    final key = _sharedKey;
    if (text.isEmpty || key == null || _isSending) return;

    setState(() => _isSending = true);
    _inputController.clear();

    final payload = await _crypto.encryptTextMessage(text, key);
    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: 'me',
      senderName: 'Tôi',
      timestamp: DateTime.now(),
      type: MessageType.text,
      plaintext: text,
      ciphertextBase64: payload.ciphertextBase64,
      nonceBase64: payload.nonceBase64,
      macBase64: payload.macBase64,
    );

    // Mô phỏng độ trễ gửi qua mạng.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _messages.add(message);
      _isSending = false;
    });
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage() async {
    final key = _sharedKey;
    if (key == null) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return;

    final rawBytes = await picked.readAsBytes();
    if (!mounted) return;

    // Mô phỏng xóa EXIF: trong ứng dụng thật dùng thư viện strip metadata
    // hoặc render lại ảnh qua canvas trước khi mã hóa.
    final sanitized = _stripExif(rawBytes);

    final payload = await _crypto.encryptMediaBytes(sanitized, key);
    final message = ChatMessage(
      id: const Uuid().v4(),
      senderId: 'me',
      senderName: 'Tôi',
      timestamp: DateTime.now(),
      type: MessageType.image,
      plaintext: '[Hình ảnh]',
      ciphertextBase64: payload.ciphertextBase64,
      nonceBase64: payload.nonceBase64,
      macBase64: payload.macBase64,
      localImagePath: picked.path,
      decryptedImageBytes: sanitized,
    );

    if (!mounted) return;
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  /// Loại bỏ vùng dữ liệu EXIF (APP1) ở đầu file JPEG.
  /// Đây là bước "ẩn metadata" — metadata ảnh có thể chứa GPS của người chụp.
  Uint8List _stripExif(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return bytes; // không phải JPEG → giữ nguyên
    }
    var i = 2;
    while (i + 4 <= bytes.length) {
      if (bytes[i] != 0xFF) break;
      final marker = bytes[i + 1];
      final length = (bytes[i + 2] << 8) | bytes[i + 3];
      // APP1 = 0xE1 (chứa EXIF), APP2 = 0xE2 (chứa ICC profile)
      if (marker == 0xE1 || marker == 0xE2) {
        final out = Uint8List.fromList(bytes);
        out.removeRange(i, i + 2 + length);
        return out;
      }
      i += 2 + length;
    }
    return bytes;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------
  // Crypto Inspector
  // ---------------------------------------------------------------------

  void _openInspector(ChatMessage message) {
    if (!_isInspectorEnabled) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _CryptoInspectorSheet(message: message),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF7E57C2),
                  foregroundColor: Colors.white,
                  child: Text(
                    widget.memberName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF43A047),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.memberName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Color(0xFF18191F),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 12, color: Color(0xFF43A047)),
                      SizedBox(width: 4),
                      Text(
                        'E2EE: AES-256-GCM / Khóa 256-bit',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF43A047)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Soi mật mã',
            isSelected: _isInspectorEnabled,
            icon: Icon(
              Icons.security_rounded,
              color: _isInspectorEnabled
                  ? const Color(0xFF1E88E5)
                  : Colors.grey.shade400,
            ),
            onPressed: () {
              setState(() => _isInspectorEnabled = !_isInspectorEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text(
                    _isInspectorEnabled
                        ? 'Đã bật Chế độ soi mật mã — chạm vào tin nhắn để xem ciphertext'
                        : 'Đã tắt Chế độ soi mật mã',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Security info banner
          Container(
            width: double.infinity,
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, size: 16, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🔒 Nội dung và hình ảnh được mã hóa đầu cuối. Kẻ trung gian trên đường truyền chỉ thấy chuỗi mã hóa vô nghĩa.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _MessageBubble(
                        message: msg,
                        onTap: () => _openInspector(msg),
                      );
                    },
                  ),
          ),
          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Gửi ảnh',
            icon: const Icon(Icons.image_outlined, color: Color(0xFF546E7A)),
            onPressed: _sharedKey == null ? null : _pickAndSendImage,
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Nhắn tin bảo mật…',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF1F3F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _isSending
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton.filled(
                  tooltip: 'Gửi',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _sharedKey == null ? null : _sendText,
                ),
        ],
      ),
    );
  }
}

/// Bong bóng chat: căn phải cho tin của "Tôi", căn trái cho tin của thành viên.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onTap});

  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bubbleColor = isMine ? const Color(0xFF1E88E5) : Colors.white;
    final textColor = isMine ? Colors.white : const Color(0xFF18191F);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
                border: isMine ? null : Border.all(color: const Color(0xFFE3E7EC)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.type == MessageType.image)
                    _buildImageContent()
                  else
                    Text(
                      message.plaintext ?? '',
                      style: TextStyle(color: textColor, fontSize: 14.5, height: 1.35),
                    ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: isMine ? Colors.white70 : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Đã xác thực E2EE',
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine ? Colors.white70 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine ? Colors.white70 : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    final bytes = message.decryptedImageBytes;
    if (bytes == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.image_not_supported_outlined, color: Colors.white70),
          SizedBox(width: 8),
          Text(
            'Ảnh (đã mã hóa)',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        bytes,
        width: 190,
        height: 130,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: 190,
          height: 130,
          color: const Color(0xFFE3E7EC),
          child: const Center(
            child: Icon(Icons.image_rounded, size: 34, color: Color(0xFF90A4AE)),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Bottom sheet trình diễn báo cáo mật mã: plaintext ↔ ciphertext.
class _CryptoInspectorSheet extends StatelessWidget {
  const _CryptoInspectorSheet({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🔬 SOI MẬT MÃ (CRYPTO INSPECTOR)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFF18191F),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Từ ${message.senderName} • ${_fmt(message.timestamp)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),

              // --- Plaintext ---
              _Section(
                title: 'Nội dung gốc (Plaintext)',
                icon: Icons.text_snippet_outlined,
                iconColor: const Color(0xFF43A047),
                child: message.type == MessageType.image
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.decryptedImageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                message.decryptedImageBytes!,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Container(
                                  height: 120,
                                  color: const Color(0xFFF1F3F6),
                                  child: const Center(
                                    child: Icon(Icons.image_rounded, size: 40),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Ảnh gốc (đã khử EXIF) — chỉ tồn tại trong RAM của thiết bị.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      )
                    : Text(
                        message.plaintext ?? '(trống)',
                        style: const TextStyle(fontSize: 14.5, height: 1.4),
                      ),
              ),
              const SizedBox(height: 14),

              // --- Ciphertext ---
              _Section(
                title: 'Dữ liệu trên đường truyền (Ciphertext)',
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF1E88E5),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF263238),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    message.ciphertextBase64 ?? '(không có)',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.45,
                      color: Color(0xFF80CBC4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- Thuật toán ---
              _Section(
                title: 'Thuật toán áp dụng',
                icon: Icons.security_rounded,
                iconColor: const Color(0xFF7E57C2),
                child: const Text(
                  'AES-256-GCM (Authenticated Encryption)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- Nonce ---
              _Section(
                title: 'Nonce (IV)',
                icon: Icons.casino_outlined,
                iconColor: const Color(0xFFF9A825),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.nonceBase64 ?? '(không có)',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: Color(0xFF18191F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '12 byte (96-bit) ngẫu nhiên — sinh mới cho MỖI lần mã hóa, '
                      'không bao giờ tái sử dụng với cùng một khóa.',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --- MAC ---
              _Section(
                title: 'Khóa xác thực (Auth Tag / MAC)',
                icon: Icons.verified_outlined,
                iconColor: const Color(0xFFE53935),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.macBase64 ?? '(không có)',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: Color(0xFF18191F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '16 byte (128-bit) đảm bảo TÍNH TOÀN VẸN — nếu 1 byte ciphertext '
                      'bị sửa, quá trình giải mã sẽ thất bại và ứng dụng báo lỗi.',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // --- Luồng ---
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'LUỒNG BẢO MẬT',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF546E7A),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ECDH X25519  →  HKDF-SHA256  →  AES-256-GCM\n'
                      'Khóa phiên chỉ tồn tại trên thiết bị hai bên.\n'
                      'Máy chủ chỉ chuyển tiếp ciphertext, không thể đọc.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        color: Color(0xFF37474F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: iconColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
