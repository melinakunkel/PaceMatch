/// A private, invite-only space ("Kreis") — e.g. a friend group — that can
/// be switched into so Sportplan, Entdecken and Sportbuddys only show that
/// circle's own activities and matches instead of the public pool.
class Circle {
  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  Circle({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
  });

  factory Circle.fromMap(Map<String, dynamic> map) => Circle(
    id: map['id'] as String,
    name: map['name'] as String,
    inviteCode: map['invite_code'] as String,
    createdBy: map['created_by'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
