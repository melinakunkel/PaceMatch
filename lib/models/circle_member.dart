import 'profile.dart';

/// A [Circle]'s member together with their role in it — 'admin' can edit
/// the circle and manage its other members, 'member' cannot.
class CircleMember {
  final Profile profile;
  final String role;
  final DateTime joinedAt;

  CircleMember({
    required this.profile,
    required this.role,
    required this.joinedAt,
  });

  bool get isAdmin => role == 'admin';

  factory CircleMember.fromMap(Map<String, dynamic> map) => CircleMember(
    profile: Profile.fromMap(map['profiles'] as Map<String, dynamic>),
    role: map['role'] as String,
    joinedAt: DateTime.parse(map['joined_at'] as String),
  );
}
