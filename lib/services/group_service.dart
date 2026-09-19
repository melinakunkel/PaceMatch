import '../models/activity.dart';
import '../models/group.dart';
import '../models/profile.dart';
import '../models/sport_type.dart';
import 'supabase_service.dart';

class GroupService {
  final _client = SupabaseService.client;

  /// Creates a group from a matched activity and adds the creator as the
  /// first member.
  Future<SportGroup> createGroup({
    required String createdBy,
    required SportType sport,
    required String name,
    String? meetingPoint,
    DateTime? meetingTime,
    String? activityId,
  }) async {
    await SupabaseService.ensureFreshSession();
    final map = await _client
        .from('groups')
        .insert({
          'name': name,
          'sport': sport.name,
          'created_by': createdBy,
          'meeting_point': meetingPoint,
          'meeting_time': meetingTime?.toIso8601String(),
          'activity_id': activityId,
        })
        .select()
        .single();
    final group = SportGroup.fromMap(map);
    await joinGroup(groupId: group.id, userId: createdBy);
    return group;
  }

  Future<void> joinGroup({required String groupId, required String userId}) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('group_members').upsert({
      'group_id': groupId,
      'user_id': userId,
    }, onConflict: 'group_id,user_id');
  }

  Future<void> updateMeetingPoint({
    required String groupId,
    required String meetingPoint,
    DateTime? meetingTime,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('groups').update({
      'meeting_point': meetingPoint,
      if (meetingTime != null) 'meeting_time': meetingTime.toIso8601String(),
    }).eq('id', groupId);
  }

  Future<SportGroup> getGroup(String groupId) async {
    final map = await _client
        .from('groups')
        .select('*, group_members(count)')
        .eq('id', groupId)
        .single();
    final countRows = map['group_members'] as List?;
    final count = countRows != null && countRows.isNotEmpty
        ? (countRows.first['count'] as int? ?? 0)
        : 0;
    return SportGroup.fromMap({...map, 'member_count': count});
  }

  Future<List<SportGroup>> getMyGroups(String userId) async {
    final rows = await _client
        .from('group_members')
        .select('groups(*, group_members(count))')
        .eq('user_id', userId);

    final groups = <SportGroup>[];
    for (final row in rows) {
      final g = row['groups'] as Map<String, dynamic>?;
      if (g == null) continue;
      final countRows = g['group_members'] as List?;
      final count = countRows != null && countRows.isNotEmpty
          ? (countRows.first['count'] as int? ?? 0)
          : 0;
      groups.add(SportGroup.fromMap({...g, 'member_count': count}));
    }
    groups.sort((a, b) =>
        (b.meetingTime ?? DateTime(2100)).compareTo(a.meetingTime ?? DateTime(2100)));
    return groups;
  }

  Future<List<Profile>> getGroupMembers(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select('profiles(*)')
        .eq('group_id', groupId);
    return rows
        .map((row) => Profile.fromMap(row['profiles'] as Map<String, dynamic>))
        .toList();
  }

  Future<Activity?> getActivity(String? activityId) async {
    if (activityId == null) return null;
    final map = await _client
        .from('activities')
        .select()
        .eq('id', activityId)
        .maybeSingle();
    return map == null ? null : Activity.fromMap(map);
  }
}
