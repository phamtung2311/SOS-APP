import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sos_safe_family/data/services/crypto_service.dart';
import 'package:sos_safe_family/data/services/secure_storage_service.dart';

/// Hồ sơ người dùng kèm thông tin an toàn & khóa mật mã X25519.
class UserSecurityProfile {
  const UserSecurityProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.publicKeyB64,
    required this.publicKeyFingerprint,
    this.isKeystoreProtected = true,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  /// Khóa công khai X25519 (44 ký tự Base64, 32 byte).
  final String publicKeyB64;

  /// Mã vân tay kiểm toán khóa công khai (8 cặp hex, ví dụ `A1:B2:C3:...`).
  final String publicKeyFingerprint;

  /// Trạng thái bảo vệ bằng phần cứng (Android Keystore / TEE).
  final bool isKeystoreProtected;

  UserSecurityProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoUrl,
    String? publicKeyB64,
    String? publicKeyFingerprint,
    bool? isKeystoreProtected,
  }) {
    return UserSecurityProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      publicKeyB64: publicKeyB64 ?? this.publicKeyB64,
      publicKeyFingerprint: publicKeyFingerprint ?? this.publicKeyFingerprint,
      isKeystoreProtected: isKeystoreProtected ?? this.isKeystoreProtected,
    );
  }
}

/// Dịch vụ Xác thực người dùng (Google Sign-In + Firebase Auth)
/// kết hợp cơ chế Key Provisioning (Android Keystore + Firestore).
class AuthService {
  AuthService({
    this.auth,
    GoogleSignIn? googleSignIn,
    this.firestore,
    CryptoService? cryptoService,
    SecureStorageService? secureStorage,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _crypto = cryptoService ?? CryptoService(),
        _storage = secureStorage ?? SecureStorageService();

  final fb_auth.FirebaseAuth? auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore? firestore;
  final CryptoService _crypto;
  final SecureStorageService _storage;

  fb_auth.FirebaseAuth get _safeAuth => auth ?? fb_auth.FirebaseAuth.instance;
  FirebaseFirestore get _safeFirestore =>
      firestore ?? FirebaseFirestore.instance;

  UserSecurityProfile? _currentProfile;
  UserSecurityProfile? get currentProfile => _currentProfile;

  /// Lắng nghe trạng thái đăng nhập Firebase Auth và tự động nạp khóa.
  Stream<UserSecurityProfile?> authStateChanges() {
    try {
      return _safeAuth.authStateChanges().asyncMap((fbUser) async {
        if (fbUser == null) {
          _currentProfile = null;
          return null;
        }
        return await provisionOrLoadUserKeys(
          uid: fbUser.uid,
          displayName: fbUser.displayName ?? 'Người dùng',
          email: fbUser.email ?? '',
          photoUrl: fbUser.photoURL,
        );
      });
    } catch (e) {
      debugPrint('[AuthService] authStateChanges offline fallback: $e');
      return Stream.value(_currentProfile);
    }
  }

  /// Đăng nhập bằng tài khoản Google, xác thực qua Firebase Auth,
  /// sau đó tự động sinh hoặc nạp khóa X25519 từ Android Keystore.
  Future<UserSecurityProfile?> signInWithGoogle() async {
    try {
      // 1. Kích hoạt luồng OAuth Google Sign-In trên thiết bị
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Người dùng hủy hộp thoại đăng nhập
        return null;
      }

      // 2. Lấy access token và ID token từ Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Tạo credential cho Firebase Auth
      final fb_auth.AuthCredential credential =
          fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Đăng nhập vào Firebase Auth
      final fb_auth.UserCredential userCredential =
          await _safeAuth.signInWithCredential(credential);
      final fbUser = userCredential.user;
      if (fbUser == null) return null;

      // 5. Sinh / Nạp khóa X25519 gắn với UID người dùng
      final profile = await provisionOrLoadUserKeys(
        uid: fbUser.uid,
        displayName:
            fbUser.displayName ?? googleUser.displayName ?? 'Người dùng',
        email: fbUser.email ?? googleUser.email,
        photoUrl: fbUser.photoURL ?? googleUser.photoUrl,
      );

      _currentProfile = profile;
      return profile;
    } catch (e) {
      debugPrint('[AuthService] Lỗi signInWithGoogle: $e');
      rethrow;
    }
  }

  /// Tự động sinh khóa mới hoặc nạp khóa X25519 đã có trong Android Keystore.
  Future<UserSecurityProfile> provisionOrLoadUserKeys({
    required String uid,
    required String displayName,
    required String email,
    String? photoUrl,
  }) async {
    // 1. Kiểm tra Android Keystore xem đã có private key cho UID này chưa
    String? privateKeyB64 = await _storage.getUserPrivateKey(uid);
    String? publicKeyB64 = await _storage.getUserPublicKey(uid);

    if (privateKeyB64 == null || publicKeyB64 == null) {
      // CHƯA CÓ: Sinh cặp khóa X25519 mới
      final keyPair = await _crypto.generateKeyPairX25519();
      publicKeyB64 = await _crypto.exportPublicKey(keyPair);
      privateKeyB64 = await _crypto.exportPrivateKey(keyPair);

      // Lưu Private Key vào Android Keystore (EncryptedSharedPreferences)
      await _storage.saveUserPrivateKey(uid, privateKeyB64);
      await _storage.saveUserPublicKey(uid, publicKeyB64);
      debugPrint(
          '[AuthService] Đã sinh và lưu khóa X25519 mới vào Keystore cho UID: $uid');
    } else {
      debugPrint(
          '[AuthService] Đã tìm thấy khóa X25519 sẵn có trong Keystore cho UID: $uid');
    }

    // 2. Tính mã vân tay an toàn SHA-256 của Public Key
    final fingerprint = await _crypto.getPublicKeyFingerprint(publicKeyB64);

    // 3. Đồng bộ Public Key lên Cloud Firestore (collection `users/{uid}`)
    try {
      final docData = <String, dynamic>{
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'publicKey': publicKeyB64,
        'fingerprint': fingerprint,
        'keystoreProtected': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (photoUrl != null) {
        docData['photoUrl'] = photoUrl;
      }
      await _safeFirestore
          .collection('users')
          .doc(uid)
          .set(docData, SetOptions(merge: true));
      debugPrint(
          '[AuthService] Đã đồng bộ Public Key lên Cloud Firestore `users/$uid`');
    } catch (e) {
      debugPrint(
          '[AuthService] Cảnh báo đồng bộ Firestore (có thể đang offline): $e');
    }

    final profile = UserSecurityProfile(
      uid: uid,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      publicKeyB64: publicKeyB64,
      publicKeyFingerprint: fingerprint,
      isKeystoreProtected: true,
    );

    _currentProfile = profile;
    return profile;
  }

  /// Đăng xuất khỏi Firebase Auth và Google Sign-In.
  /// (Lưu ý: Khóa private trong Keystore được giữ lại an toàn cho lần đăng nhập sau).
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _safeAuth.signOut();
    } catch (_) {}
    _currentProfile = null;
  }
}
