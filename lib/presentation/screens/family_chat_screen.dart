import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sos_safe_family/core/app_state.dart';
import 'package:sos_safe_family/data/models/chat_message.dart';
import 'package:sos_safe_family/data/services/auth_service.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/secure_storage_service.dart';
import 'package:uuid/uuid.dart';

/// Màn hình nhắn tin bảo mật E2EE với một thành viên gia đình.
///
/// Mọi tin nhắn đều được mã hóa AES-256-GCM bằng khóa phiên thỏa thuận qua
/// ECDH X25519 giữa hai bên trước khi "đi trên đường truyền". Nút **Soi mật mã** cho phép
/// trình diễn trực tiếp plaintext ↔ ciphertext để phục vụ báo cáo đồ án.
class FamilyChatScreen extends StatefulWidget {
  const FamilyChatScreen({
    super.key,
    required this.memberName,
    this.peerEmail,
    this.memberId,
  });

  final String memberName;
  final String? peerEmail;
  final String? memberId;

  @override
  State<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

class _FamilyChatScreenState extends State<FamilyChatScreen> {
  final CryptoService _crypto = CryptoService();
  final SecureStorageService _storage = SecureStorageService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSub;
  String _chatId = '';
  String? _myEmail;
  String? _myUid;
  String _myName = 'Tôi';

  /// Khóa phiên dùng chung cho cả hai chiều (thỏa thuận AES-256-GCM E2EE hoặc fallback demo).
  Uint8List? _sharedKey;

  /// Cờ xác định phiên chat có dùng khóa E2EE thật hay chế độ demo fallback.
  bool _isE2EE = false;
  bool _isLoading = true;
  bool _hasConnectionError = false;

  bool _isInspectorEnabled = true;
  bool _isSending = false;

  String _peerDisplayName = '';
  String? _peerEmail;
  String _resolvedPeerUid = '';
  bool _isDemoFallbackRoom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Thiết lập khóa phiên phòng chat và lắng nghe tin nhắn Firestore.
  ///
  /// Quy trình thỏa thuận khóa E2EE thật:
  /// 1. Lấy `publicKey` của đối phương (peer) từ Firestore collection `users/{peerUid}`.
  /// 2. Nạp khóa bí mật của chính mình từ Android Keystore (SecureStorage).
  /// 3. Thực hiện ECDH X25519 + HKDF-SHA256 để sinh ra cùng 1 khóa phiên AES-256.
  /// 4. Nếu thiếu peer key hoặc chưa đăng nhập: Fallback về `deriveRoomKey` và gán `_isE2EE = false`.
  Future<void> _bootstrap() async {
    UserSecurityProfile? user;
    try {
      final appState = AppScope.read(context);
      user = appState.userProfile;
      _myEmail = user?.email;
      _myUid = user?.uid;
      _myName = user?.displayName ?? 'Tôi';
    } catch (_) {}

    _peerDisplayName = widget.memberName;
    _peerEmail = widget.peerEmail;
    _resolvedPeerUid = (widget.memberId ?? '').trim();

    if (_resolvedPeerUid.isNotEmpty && AppState.isUidLike(_resolvedPeerUid)) {
      // giữ UID thật nếu peer đã có doc users
    } else if (widget.peerEmail != null && widget.peerEmail!.trim().isNotEmpty) {
      try {
        final emailLookup = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: widget.peerEmail!.trim().toLowerCase())
            .limit(1)
            .get();
        if (emailLookup.docs.isNotEmpty) {
          _resolvedPeerUid = emailLookup.docs.first.id;
        }
      } catch (_) {}
    }

    if (_myUid != null && _myUid!.isNotEmpty && _resolvedPeerUid.isNotEmpty && AppState.isUidLike(_resolvedPeerUid)) {
      _chatId = AppState.buildChatRoomId(myUid: _myUid!, peerUid: _resolvedPeerUid);
      _isDemoFallbackRoom = false;
    } else {
      final myE = (_myEmail ?? 'user_a').trim().toLowerCase();
      final peerE = (widget.peerEmail ?? widget.memberName).trim().toLowerCase();
      final sorted = [myE, peerE]..sort();
      _chatId = 'chat_${sorted[0].replaceAll(RegExp(r'[^a-z0-9]'), '_')}___${sorted[1].replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      _isDemoFallbackRoom = true;
    }

    // 1. Thử truy vấn Public Key của peer từ Cloud Firestore
    String? peerPublicKeyB64;
    try {
      final peerLookupUid = _resolvedPeerUid.isNotEmpty ? _resolvedPeerUid : widget.memberId;
      if (peerLookupUid != null && peerLookupUid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(peerLookupUid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          peerPublicKeyB64 = data['publicKey'] as String?;
          final dbName = data['displayName'] as String?;
          if (dbName != null && dbName.isNotEmpty) {
            _peerDisplayName = dbName;
          }
          final dbEmail = data['email'] as String?;
          if (dbEmail != null && dbEmail.isNotEmpty) {
            _peerEmail = dbEmail;
          }
        }
      }

      if (peerPublicKeyB64 == null && widget.peerEmail != null && widget.peerEmail!.isNotEmpty) {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: widget.peerEmail!.trim().toLowerCase())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          peerPublicKeyB64 = data['publicKey'] as String?;
          final dbName = data['displayName'] as String?;
          if (dbName != null && dbName.isNotEmpty) {
            _peerDisplayName = dbName;
          }
          final dbEmail = data['email'] as String?;
          if (dbEmail != null && dbEmail.isNotEmpty) {
            _peerEmail = dbEmail;
          }
          _resolvedPeerUid = query.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint('[FamilyChatScreen] Lỗi truy vấn Firestore lấy peer key: $e');
    }

    Uint8List? keyBytes;
    bool isE2eeSuccess = false;

    if (peerPublicKeyB64 != null && peerPublicKeyB64.isNotEmpty && _myUid != null) {
      try {
        final privB64 = await _storage.getUserPrivateKey(_myUid!);
        final pubB64 = user?.publicKeyB64 ?? await _storage.getUserPublicKey(_myUid!);
        if (privB64 != null && pubB64 != null) {
          final myKeyPair = await _crypto.importKeyPair(
            privateKeyB64: privB64,
            publicKeyB64: pubB64,
          );
          keyBytes = await _crypto.deriveChatKeyForPeer(
            myKeyPair: myKeyPair,
            theirPublicKeyB64: peerPublicKeyB64,
          );
          isE2eeSuccess = true;
          debugPrint('[FamilyChatScreen] ✅ Thiết lập khóa E2EE ECDH X25519 thành công.');
        }
      } catch (e) {
        debugPrint('[FamilyChatScreen] Lỗi thỏa thuận ECDH X25519: $e');
      }
    }

    if (!isE2eeSuccess || keyBytes == null) {
      keyBytes = await _crypto.deriveRoomKey(_chatId);
      isE2eeSuccess = false;
      debugPrint('[FamilyChatScreen] ⚠️ Thiếu peer key -> Fallback deriveRoomKey (demo)');
    }

    try {
      final membersList = <String>[];
      if (_myUid != null && _myUid!.isNotEmpty) membersList.add(_myUid!);
      if (_resolvedPeerUid.isNotEmpty && !membersList.contains(_resolvedPeerUid)) {
        membersList.add(_resolvedPeerUid);
      }
      if (membersList.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatId)
            .set({
          'members': membersList,
          'lastActivity': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[FamilyChatScreen] Cập nhật doc chats members skipped: $e');
    }

    if (!mounted) return;
    setState(() {
      _sharedKey = keyBytes;
      _isE2EE = isE2eeSuccess;
      _isLoading = true;
      _hasConnectionError = false;
    });

    debugPrint(
      '[CHAT] room=$_chatId kind=${_isDemoFallbackRoom ? 'email-fallback' : 'uid'} key=${_isE2EE ? 'E2EE' : 'demo'} myEmail=${_myEmail ?? 'null'} peerEmail=${_peerEmail ?? 'null'} myUid=${_myUid ?? 'null'} peerUid=${_resolvedPeerUid.isNotEmpty ? _resolvedPeerUid : (widget.memberId ?? 'null')}',
    );
    _listenToMessages(keyBytes);
  }

  /// Lắng nghe các tin nhắn mã hóa thời gian thực từ Firestore và giải mã E2EE.
  void _listenToMessages(Uint8List key) {
    _chatSub?.cancel();
    try {
      _chatSub = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .listen((snapshot) async {
        final List<ChatMessage> loaded = [];
        for (final doc in snapshot.docs) {
          final d = doc.data();
          final senderEmail = (d['senderEmail'] as String? ?? '').toLowerCase().trim();
          final senderId = d['senderId'] as String? ?? '';
          final senderName = d['senderName'] as String? ?? widget.memberName;
          final isMine = (senderEmail.isNotEmpty && senderEmail == _myEmail?.toLowerCase().trim()) ||
              (senderId.isNotEmpty && (senderId == _myUid || senderId == 'me'));

          final cipherB64 = d['ciphertextBase64'] as String? ?? '';
          final nonceB64 = d['nonceBase64'] as String? ?? '';
          final macB64 = d['macBase64'] as String? ?? '';
          final typeStr = d['type'] as String? ?? 'text';
          final type = typeStr == 'image' ? MessageType.image : MessageType.text;

          // Kiểm tra xem tin nhắn này đã có trong bộ nhớ RAM local chưa để tránh giải mã lại
          final existingIndex = _messages.indexWhere((m) => m.id == doc.id);
          String? text;
          Uint8List? imgBytes;
          if (existingIndex != -1) {
            text = _messages[existingIndex].plaintext;
            imgBytes = _messages[existingIndex].decryptedImageBytes;
          }

          if (text == null || (type == MessageType.image && imgBytes == null)) {
            if (cipherB64.isNotEmpty && nonceB64.isNotEmpty && macB64.isNotEmpty) {
              try {
                if (type == MessageType.text) {
                  text = await _crypto.decryptTextMessage(
                    EncryptedPayload.fromBase64(
                      ciphertextBase64: cipherB64,
                      nonceBase64: nonceB64,
                      macBase64: macB64,
                    ),
                    key,
                  );
                } else {
                  imgBytes = await _crypto.decryptMediaBytes(
                    EncryptedPayload.fromBase64(
                      ciphertextBase64: cipherB64,
                      nonceBase64: nonceB64,
                      macBase64: macB64,
                    ),
                    key,
                  );
                  text = '[Hình ảnh]';
                }
              } catch (e) {
                debugPrint('[FamilyChatScreen] Lỗi giải mã: $e');
                text = '[Không thể giải mã: Sai khóa E2EE]';
              }
            } else {
              text = (d['plaintext'] as String?) ?? '';
            }
          }

          final ts = d['createdAt'] as Timestamp?;
          final time = ts?.toDate() ?? DateTime.now();

          loaded.add(ChatMessage(
            id: doc.id,
            senderId: isMine ? 'me' : 'other',
            senderName: isMine ? 'Tôi' : senderName,
            timestamp: time,
            type: type,
            plaintext: text,
            ciphertextBase64: cipherB64,
            nonceBase64: nonceB64,
            macBase64: macB64,
            decryptedImageBytes: imgBytes,
            isEncrypted: _isE2EE,
            status: MessageStatus.sent,
          ));
        }

        // Giữ lại các tin local đang pending/failed chưa được đồng bộ lên Firestore
        final pending = _messages.where((m) =>
            (m.status == MessageStatus.failed || m.status == MessageStatus.sending) &&
            !loaded.any((l) => l.id == m.id)).toList();

        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(loaded);
            _messages.addAll(pending);
            _isLoading = false;
            _hasConnectionError = false;
          });
          _scrollToBottom();
        }
      }, onError: (e) {
        debugPrint('[FamilyChatScreen] Firestore offline: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasConnectionError = true;
          });
        }
      });
    } catch (e) {
      debugPrint('[FamilyChatScreen] Firestore init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasConnectionError = true;
        });
      }
    }
  }

  // ---------------------------------------------------------------------
  // Gửi tin nhắn E2EE (Không gửi plaintext lên Firestore)
  // ---------------------------------------------------------------------

  Future<void> _sendText() async {
    final text = _inputController.text.trim();
    final key = _sharedKey;
    if (text.isEmpty || key == null || _isSending) return;

    _inputController.clear();

    final payload = await _crypto.encryptTextMessage(text, key);
    final msgId = const Uuid().v4();

    // Plaintext chỉ lưu trong RAM local của thiết bị
    final localMsg = ChatMessage(
      id: msgId,
      senderId: 'me',
      senderName: _myName,
      timestamp: DateTime.now(),
      type: MessageType.text,
      plaintext: text,
      ciphertextBase64: payload.ciphertextBase64,
      nonceBase64: payload.nonceBase64,
      macBase64: payload.macBase64,
      isEncrypted: _isE2EE,
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.add(localMsg);
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final docMap = localMsg.toFirestoreMap(
        senderEmail: _myEmail ?? '',
        createdAt: FieldValue.serverTimestamp(),
      );
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(msgId)
          .set(docMap);

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(status: MessageStatus.sent);
          }
        });
      }
    } catch (e) {
      debugPrint('[FamilyChatScreen] Firestore send error: $e');
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(status: MessageStatus.failed);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
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

    // Loại bỏ EXIF metadata để bảo vệ quyền riêng tư vị trí khi gửi ảnh
    final sanitized = _stripExif(rawBytes);
    final payload = await _crypto.encryptMediaBytes(sanitized, key);
    final msgId = const Uuid().v4();

    // Plaintext / ảnh gốc chỉ lưu trong RAM local
    final localMsg = ChatMessage(
      id: msgId,
      senderId: 'me',
      senderName: _myName,
      timestamp: DateTime.now(),
      type: MessageType.image,
      plaintext: '[Hình ảnh]',
      ciphertextBase64: payload.ciphertextBase64,
      nonceBase64: payload.nonceBase64,
      macBase64: payload.macBase64,
      localImagePath: picked.path,
      decryptedImageBytes: sanitized,
      isEncrypted: _isE2EE,
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.add(localMsg);
    });
    _scrollToBottom();

    try {
      final docMap = localMsg.toFirestoreMap(
        senderEmail: _myEmail ?? '',
        createdAt: FieldValue.serverTimestamp(),
      );
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(msgId)
          .set(docMap);

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(status: MessageStatus.sent);
          }
        });
      }
    } catch (e) {
      debugPrint('[FamilyChatScreen] Gửi ảnh Firestore error: $e');
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(status: MessageStatus.failed);
          }
        });
      }
    } finally {
      if (mounted) _scrollToBottom();
    }
  }

  /// Thử gửi lại tin nhắn bị lỗi
  Future<void> _retrySendMessage(ChatMessage failedMsg) async {
    final key = _sharedKey;
    if (key == null) return;

    setState(() {
      final idx = _messages.indexWhere((m) => m.id == failedMsg.id);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(status: MessageStatus.sending);
      }
    });

    try {
      final docMap = failedMsg.toFirestoreMap(
        senderEmail: _myEmail ?? '',
        createdAt: FieldValue.serverTimestamp(),
      );
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(failedMsg.id)
          .set(docMap);

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == failedMsg.id);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(status: MessageStatus.sent);
          }
        });
      }
    } catch (e) {
      debugPrint('[FamilyChatScreen] Retry write error: $e');
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == failedMsg.id);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(status: MessageStatus.failed);
          }
        });
      }
    }
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
        toolbarHeight: 78,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF7E57C2),
                  foregroundColor: Colors.white,
                  child: Text(
                    (_peerDisplayName.isNotEmpty ? _peerDisplayName : widget.memberName)
                        .characters
                        .firstOrNull
                        ?.toUpperCase() ??
                        '?',
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
                      color: _isE2EE ? const Color(0xFF43A047) : const Color(0xFFE65100),
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
                    _peerDisplayName.isNotEmpty ? _peerDisplayName : widget.memberName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF18191F),
                    ),
                  ),
                  if (_peerEmail != null && _peerEmail!.isNotEmpty)
                    Text(
                      _peerEmail!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  Row(
                    children: [
                      Icon(
                        _isE2EE ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 11,
                        color: _isE2EE ? const Color(0xFF43A047) : const Color(0xFFE65100),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isE2EE
                            ? 'E2EE: ECDH X25519 / AES-256-GCM'
                            : (_isDemoFallbackRoom ? 'DEMO: Khóa fallback (room)' : 'DEMO: Khóa dẫn xuất'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _isE2EE ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'room=${_chatId.isNotEmpty ? _chatId : 'unknown'} | kind=${_isDemoFallbackRoom ? 'email-fallback' : 'uid'} | key=${_isE2EE ? 'E2EE' : 'demo'} | myEmail=${(_myEmail ?? '').isNotEmpty ? _myEmail : 'n/a'} | peerEmail=${(_peerEmail ?? '').isNotEmpty ? _peerEmail : 'n/a'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF607D8B)),
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
          // Security / Warning info banner ở đầu hội thoại
          if (!_isE2EE)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF3E0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE65100)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chưa thiết lập khóa E2EE – chế độ demo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
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
                      '🔒 Nội dung và hình ảnh được mã hóa đầu cuối (E2EE X25519). Kẻ trung gian trên đường truyền chỉ thấy chuỗi mã hóa vô nghĩa.',
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

          // Messages View
          Expanded(
            child: _isLoading && _messages.isEmpty && !_hasConnectionError
                ? const Center(child: CircularProgressIndicator())
                : _hasConnectionError && _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 54,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Không kết nối được máy chủ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF37474F),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Vui lòng kiểm tra lại kết nối mạng và thử lại.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _hasConnectionError = false;
                                  });
                                  _bootstrap();
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Thử lại'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E88E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 54,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Chưa có tin nhắn nào',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF546E7A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hãy gửi tin nhắn đầu tiên để bắt đầu trò chuyện',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              return _MessageBubble(
                                message: msg,
                                onTap: () => _openInspector(msg),
                                onRetry: msg.status == MessageStatus.failed
                                    ? () => _retrySendMessage(msg)
                                    : null,
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
  const _MessageBubble({
    required this.message,
    required this.onTap,
    this.onRetry,
  });

  final ChatMessage message;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

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
                maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                      if (message.status == MessageStatus.failed) ...[
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 13,
                          color: Color(0xFFFFCDD2),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          'Gửi thất bại',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFCDD2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (onRetry != null)
                          InkWell(
                            onTap: onRetry,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded, size: 11, color: Colors.white),
                                  SizedBox(width: 2),
                                  Text(
                                    'Thử gửi lại',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ] else if (message.status == MessageStatus.sending) ...[
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isMine ? Colors.white70 : Colors.grey.shade500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Đang gửi…',
                          style: TextStyle(
                            fontSize: 10,
                            color: isMine ? Colors.white70 : Colors.grey.shade500,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          message.isEncrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
                          size: 11,
                          color: isMine ? Colors.white70 : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          message.isEncrypted ? 'Đã xác thực E2EE' : 'Chế độ demo',
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
