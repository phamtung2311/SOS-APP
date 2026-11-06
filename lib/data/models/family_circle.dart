import 'package:cloud_firestore/cloud_firestore.dart';

enum CircleRole { owner, member }

/// Một thành viên trong vòng tròn gia đình.
class CircleMember {
  const CircleMember({
    required this.userId,
    required this.displayName,
    this.role = CircleRole.member,
    this.canSeeLocation = true,
    this.joinedAt,
  });

  final String userId;
  final String displayName;
  final CircleRole role;
  final bool canSeeLocation;
  final Timestamp? joinedAt;

  factory CircleMember.fromJson(Map<String, dynamic> json) => CircleMember(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? 'Người dùng',
        role: _roleFromName(json['role'] as String?),
        canSeeLocation: json['canSeeLocation'] as bool? ?? true,
        joinedAt: json['joinedAt'] as Timestamp?,
      );

  /// Parse role an toàn — trả về [CircleRole.member] nếu dữ liệu lạ
  /// (tránh crash app khi Firestore chứa giá trị không hợp lệ).
  static CircleRole _roleFromName(String? name) => switch (name) {
        'owner' => CircleRole.owner,
        'member' => CircleRole.member,
        _ => CircleRole.member,
      };

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'role': role.name,
        'canSeeLocation': canSeeLocation,
        'joinedAt': joinedAt,
      };
}

/// Vòng tròn gia đình — nhóm các thành viên cùng chia sẻ vị trí/SOS.
class FamilyCircle {
  const FamilyCircle({
    required this.circleId,
    required this.name,
    required this.members,
    this.ownedBy,
    this.createdAt,
  });

  final String circleId;
  final String name;
  final List<CircleMember> members;
  final String? ownedBy;
  final Timestamp? createdAt;

  String get publicId => 'circles/$circleId';

  factory FamilyCircle.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const <String, dynamic>{};
    final rawMembers = d['members'] as List<dynamic>? ?? const [];
    final members = rawMembers
        .whereType<Map<String, dynamic>>()
        .map(CircleMember.fromJson)
        .toList();
    return FamilyCircle(
      circleId: doc.id,
      name: d['name'] as String? ?? 'Vòng tròn gia đình',
      members: members,
      ownedBy: d['ownedBy'] as String?,
      createdAt: d['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
        'ownedBy': ownedBy,
        'createdAt': FieldValue.serverTimestamp(),
      };

  bool containsUser(String userId) => members.any((m) => m.userId == userId);

  CircleMember? memberById(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }
}
