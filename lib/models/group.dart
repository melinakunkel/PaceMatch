import '../l10n/strings.dart';
import 'profile.dart';
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

  /// A private 1:1 chat — exactly one per pair of people, reused for all
  /// their meetups. Everything else is a group chat (events, group chats
  /// created on purpose).
  final bool isDirect;

  /// The other person in a private chat, loaded separately — its title is
  /// their name, from each side's perspective.
  final Profile? partner;

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
    this.isDirect = false,
    this.partner,
  });

  /// What to call this chat: the other person's first name for a private
  /// chat, the group's own name otherwise.
  String get displayName {
    if (!isDirect) return name;
    return partner?.firstName ?? t('chatList.directChat');
  }

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
    isDirect: map['is_direct'] as bool? ?? false,
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
    Profile? partner,
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
    isDirect: isDirect,
    partner: partner ?? this.partner,
  );
}
