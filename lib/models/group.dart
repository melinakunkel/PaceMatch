import 'sport_type.dart';

class SportGroup {
  final String id;
  final String name;
  final SportType sport;
  final String createdBy;
  final String? meetingPoint;
  final double? latitude;
  final double? longitude;
  final DateTime? meetingTime;
  final String? activityId;
  final int memberCount;
  final bool hasUnread;
  final bool archived;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;

  SportGroup({
    required this.id,
    required this.name,
    required this.sport,
    required this.createdBy,
    this.meetingPoint,
    this.latitude,
    this.longitude,
    this.meetingTime,
    this.activityId,
    this.memberCount = 0,
    this.hasUnread = false,
    this.archived = false,
    this.createdAt,
    this.lastMessageAt,
  });

  bool get hasMapLocation => latitude != null && longitude != null;

  factory SportGroup.fromMap(Map<String, dynamic> map) => SportGroup(
    id: map['id'] as String,
    name: map['name'] as String,
    sport: SportType.fromDb(map['sport'] as String),
    createdBy: map['created_by'] as String,
    meetingPoint: map['meeting_point'] as String?,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    meetingTime: map['meeting_time'] == null
        ? null
        : DateTime.parse(map['meeting_time'] as String),
    activityId: map['activity_id'] as String?,
    memberCount: map['member_count'] as int? ?? 0,
    createdAt: map['created_at'] == null
        ? null
        : DateTime.parse(map['created_at'] as String),
  );

  /// The most recent activity in this chat — its last message, or when it
  /// was created if nobody has posted yet. Used to decide staleness for
  /// auto-archiving.
  DateTime? get lastActivityAt => lastMessageAt ?? createdAt;

  SportGroup copyWith({
    bool? hasUnread,
    bool? archived,
    DateTime? lastMessageAt,
  }) => SportGroup(
    id: id,
    name: name,
    sport: sport,
    createdBy: createdBy,
    meetingPoint: meetingPoint,
    latitude: latitude,
    longitude: longitude,
    meetingTime: meetingTime,
    activityId: activityId,
    memberCount: memberCount,
    hasUnread: hasUnread ?? this.hasUnread,
    archived: archived ?? this.archived,
    createdAt: createdAt,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
  );
}
