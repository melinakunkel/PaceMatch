import 'package:supabase_flutter/supabase_flutter.dart';

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
    double? latitude,
    double? longitude,
    DateTime? meetingTime,
    String? activityId,
    bool isMatch = false,
  }) async {
    await SupabaseService.ensureFreshSession();
    final map = await _client
        .from('groups')
        .insert({
          'name': name,
          'sport': sport.name,
          'created_by': createdBy,
          'meeting_point': meetingPoint,
          'latitude': latitude,
          'longitude': longitude,
          'meeting_time': meetingTime?.toUtc().toIso8601String(),
          'activity_id': activityId,
          'is_match': isMatch,
        })
        .select()
        .single();
    final group = SportGroup.fromMap(map);
    await joinGroup(groupId: group.id, userId: createdBy);
    return group;
  }

  /// A group both [userId] and I are already members of, if any — used to
  /// avoid spinning up a second chat for the same person.
  Future<String?> findSharedGroupId(String userId) async {
    final rows = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);
    return rows.isEmpty ? null : rows.first['group_id'] as String;
  }

  /// A group I already created for this activity, if any.
  Future<String?> findGroupIdForActivity(String activityId) async {
    final rows = await _client
        .from('groups')
        .select('id')
        .eq('activity_id', activityId)
        .limit(1);
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  Future<void> joinGroup({
    required String groupId,
    required String userId,
  }) async {
    await SupabaseService.ensureFreshSession();
    try {
      await _client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation: already a member, nothing to do.
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> updateMeetingPoint({
    required String groupId,
    required String meetingPoint,
    double? latitude,
    double? longitude,
    DateTime? meetingTime,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('groups')
        .update({
          'meeting_point': meetingPoint,
          'latitude': latitude,
          'longitude': longitude,
          if (meetingTime != null)
            'meeting_time': meetingTime.toUtc().toIso8601String(),
        })
        .eq('id', groupId);
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

  Future<List<SportGroup>> getMyGroups(
    String userId, {
    bool archived = false,
  }) async {
    final rows = await _client
        .from('group_members')
        .select('last_read_at, archived, groups(*, group_members(count))')
        .eq('user_id', userId)
        .limit(300);

    final groups = <SportGroup>[];
    final lastReadByGroupId = <String, DateTime?>{};
    final archivedByGroupId = <String, bool>{};
    for (final row in rows) {
      final g = row['groups'] as Map<String, dynamic>?;
      if (g == null) continue;
      final countRows = g['group_members'] as List?;
      final count = countRows != null && countRows.isNotEmpty
          ? (countRows.first['count'] as int? ?? 0)
          : 0;
      final group = SportGroup.fromMap({...g, 'member_count': count});
      groups.add(group);
      lastReadByGroupId[group.id] = row['last_read_at'] == null
          ? null
          : DateTime.parse(row['last_read_at'] as String);
      archivedByGroupId[group.id] = row['archived'] as bool? ?? false;
    }
    if (groups.isEmpty) return groups;

    final latestMessageByGroupId = await _latestMessageTimes(
      groups.map((g) => g.id).toList(),
    );
    final withUnread = <SportGroup>[];
    final resurfaced = <String>[];
    for (final g in groups) {
      final lastMessageAt = latestMessageByGroupId[g.id];
      final lastReadAt = lastReadByGroupId[g.id];
      final unread =
          lastMessageAt != null &&
          (lastReadAt == null || lastMessageAt.isAfter(lastReadAt));
      // A new message pulls an archived chat back into the active list —
      // otherwise it would arrive with no dot and nowhere visible.
      var isArchived = archivedByGroupId[g.id] ?? false;
      if (isArchived && unread) {
        resurfaced.add(g.id);
        isArchived = false;
      }
      if (isArchived != archived) continue;
      withUnread.add(
        g.copyWith(
          hasUnread: unread,
          archived: isArchived,
          lastMessageAt: lastMessageAt,
        ),
      );
    }
    for (final id in resurfaced) {
      await setArchived(groupId: id, userId: userId, archived: false);
    }

    withUnread.sort(
      (a, b) => (b.meetingTime ?? DateTime(2100)).compareTo(
        a.meetingTime ?? DateTime(2100),
      ),
    );
    return withUnread;
  }

  /// Archives (for [userId] only) any of their non-archived chats with no
  /// activity for [inactiveFor] — used when the user has opted into
  /// auto-archiving inactive chats.
  Future<void> archiveStaleChats(
    String userId, {
    Duration inactiveFor = const Duration(days: 7),
  }) async {
    final groups = await getMyGroups(userId);
    final cutoff = DateTime.now().subtract(inactiveFor);
    for (final g in groups) {
      final lastActivity = g.lastActivityAt;
      if (lastActivity != null && lastActivity.isBefore(cutoff)) {
        await setArchived(groupId: g.id, userId: userId, archived: true);
      }
    }
  }

  Future<Map<String, DateTime>> _latestMessageTimes(
    List<String> groupIds,
  ) async {
    if (groupIds.isEmpty) return {};
    final rows = await _client
        .from('messages')
        .select('group_id, created_at')
        .inFilter('group_id', groupIds)
        .order('created_at', ascending: false);
    final result = <String, DateTime>{};
    for (final row in rows) {
      final groupId = row['group_id'] as String;
      result.putIfAbsent(
        groupId,
        () => DateTime.parse(row['created_at'] as String),
      );
    }
    return result;
  }

  /// Whether any of my (non-archived) groups has a message I haven't seen —
  /// drives the unread dot on the Chat tab.
  Future<bool> hasAnyUnread(String userId) async {
    final groups = await getMyGroups(userId);
    return groups.any((g) => g.hasUnread);
  }

  Future<void> markGroupRead({
    required String groupId,
    required String userId,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('group_members')
        .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> setArchived({
    required String groupId,
    required String userId,
    required bool archived,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('group_members')
        .update({'archived': archived})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Removes me from the group without affecting other members.
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Permanently deletes the group for everyone — only the creator can do
  /// this (enforced by RLS).
  Future<void> deleteGroup(String groupId) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('groups').delete().eq('id', groupId);
  }

  Future<List<Profile>> getGroupMembers(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select('profiles(*)')
        .eq('group_id', groupId)
        .limit(300);
    return rows
        .map((row) => Profile.fromMap(row['profiles'] as Map<String, dynamic>))
        .toList();
  }

  /// Whether I confirmed attending this meetup — null means not checked in
  /// yet.
  Future<bool?> getAttendance({
    required String groupId,
    required String userId,
  }) async {
    final row = await _client
        .from('group_members')
        .select('attended')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();
    return row?['attended'] as bool?;
  }

  /// Records whether I actually showed up to a past meetup — feeds into my
  /// reliability score (see [ProfileService.recomputeReliabilityScore]).
  Future<void> checkIn({
    required String groupId,
    required String userId,
    required bool attended,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('group_members')
        .update({'attended': attended})
        .eq('group_id', groupId)
        .eq('user_id', userId);
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
