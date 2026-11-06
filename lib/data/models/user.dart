import 'package:cloud_firestore/cloud_firestore.dart';

/// Tài khoản người dùng.
///
/// Public key (X25519) lưu dạng base64 trong Firestore — đây là phần công khai.
/// Private key **không bao giờ** hiện diện trong model này (nằm ở secure storage).
class User {
  const User({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.publicKeyB64,
    this.phoneVerified = false,
    this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;

  /// Khóa công khai X25519 (32 bytes → 44 chars base64).
  final String publicKeyB64;

  final bool phoneVerified;
  final Timestamp? createdAt;

  String get publicId => 'users/$uid';

  factory User.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const <String, dynamic>{};
    return User(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? 'Người dùng',
      email: d['email'] as String? ?? '',
      publicKeyB64: d['publicKey'] as String? ?? '',
      phoneVerified: d['phoneVerified'] as bool? ?? false,
      createdAt: d['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'displayName': displayName,
        'email': email,
        'publicKey': publicKeyB64,
        'phoneVerified': phoneVerified,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
