import 'sport_type.dart';

class SportGroup {
  final String id;
  final String name;
  final SportType sport;
  final String createdBy;
  final String? meetingPoint;
  final DateTime? meetingTime;
  final String? activityId;
  final int memberCount;

  SportGroup({
    required this.id,
    required this.name,
    required this.sport,
    required this.createdBy,
    this.meetingPoint,
    this.meetingTime,
    this.activityId,
    this.memberCount = 0,
  });

  factory SportGroup.fromMap(Map<String, dynamic> map) => SportGroup(
        id: map['id'] as String,
        name: map['name'] as String,
        sport: SportType.fromDb(map['sport'] as String),
        createdBy: map['created_by'] as String,
        meetingPoint: map['meeting_point'] as String?,
        meetingTime: map['meeting_time'] == null
            ? null
            : DateTime.parse(map['meeting_time'] as String),
        activityId: map['activity_id'] as String?,
        memberCount: map['member_count'] as int? ?? 0,
      );
}
