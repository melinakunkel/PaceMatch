import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity.dart';
import '../models/group.dart';
import '../models/meetup_review.dart';
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
    bool isDirect = false,
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
          if (isDirect) 'is_direct': true,
        })
        .select()
        .single();
    final group = SportGroup.fromMap(map);
    await joinGroup(groupId: group.id, userId: createdBy);
    return group;
  }

  /// My private chat with [otherUserId], if there is one. Only chats I'm a
  /// member of are visible (RLS), so this never finds someone else's.
  Future<String?> findDirectChatId(String otherUserId) async {
    final rows = await _client
        .from('group_members')
        .select('group_id, groups!inner(is_direct, created_at)')
        .eq('user_id', otherUserId)
        .eq('groups.is_direct', true);
    if (rows.isEmpty) return null;
    rows.sort((a, b) {
      final ga = a['groups'] as Map<String, dynamic>;
      final gb = b['groups'] as Map<String, dynamic>;
      return (gb['created_at'] as String? ?? '').compareTo(
        ga['created_at'] as String? ?? '',
      );
    });
    return rows.first['group_id'] as String;
  }

  /// The one private chat between me and [otherUserId] — every "message
  /// this person" entry point (Entdecken, profile, chat request, match,
  /// Sportbuddys) leads here, so there's never a second chat with the same
  /// person. When a meetup is given, it becomes the chat's next meetup
  /// unless an upcoming one is already set.
  Future<String> openDirectChat({
    required String myId,
    required String otherUserId,
    SportType sport = SportType.sonstige,
    String? meetingPoint,
    double? latitude,
    double? longitude,
    DateTime? meetingTime,
    String? activityId,
    bool isMatch = false,
  }) async {
    final existingId = await findDirectChatId(otherUserId);
    if (existingId == null) {
      final group = await createGroup(
        createdBy: myId,
        sport: sport,
        // Never shown — a private chat is titled with the other person's
        // name from each side's perspective (see SportGroup.displayName).
        name: 'Privater Chat',
        meetingPoint: meetingPoint,
        latitude: latitude,
        longitude: longitude,
        meetingTime: meetingTime,
        activityId: activityId,
        isMatch: isMatch,
        isDirect: true,
      );
      await joinGroup(groupId: group.id, userId: otherUserId);
      return group.id;
    }
    if (meetingTime != null) {
      try {
        final current = await getGroup(existingId);
        final upcoming = current.meetingTime?.isAfter(DateTime.now()) ?? false;
        if (!upcoming) {
          await SupabaseService.ensureFreshSession();
          await _client
              .from('groups')
              .update({
                'sport': sport.name,
                'meeting_point': meetingPoint,
                'latitude': latitude,
                'longitude': longitude,
                'meeting_time': meetingTime.toUtc().toIso8601String(),
                'activity_id': activityId,
              })
              .eq('id', existingId);
        }
      } catch (_) {
        // Best-effort — the chat itself still opens; the meetup can be set
        // in there.
      }
    }
    return existingId;
  }

  /// The group chat already created for this activity, if any.
  Future<String?> findGroupIdForActivity(String activityId) async {
    final rows = await _client
        .from('groups')
        .select('id')
        .eq('activity_id', activityId)
        .eq('is_direct', false)
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

    final partners = await _partnersByGroupId(
      withUnread.where((g) => g.isDirect).map((g) => g.id).toList(),
      userId,
    );
    for (var i = 0; i < withUnread.length; i++) {
      final partner = partners[withUnread[i].id];
      if (partner != null) {
        withUnread[i] = withUnread[i].copyWith(partner: partner);
      }
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

  /// The other person in each of these private chats.
  Future<Map<String, Profile>> _partnersByGroupId(
    List<String> groupIds,
    String myId,
  ) async {
    if (groupIds.isEmpty) return {};
    final rows = await _client
        .from('group_members')
        .select('group_id, profiles(*)')
        .inFilter('group_id', groupIds)
        .neq('user_id', myId);
    return {
      for (final row in rows)
        if (row['profiles'] != null)
          row['group_id'] as String: Profile.fromMap(
            row['profiles'] as Map<String, dynamic>,
          ),
    };
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

  /// The meeting time I last answered "did it happen?" for — a private
  /// chat is reused for several meetups, so the prompt comes back whenever
  /// the chat's meeting time differs from this. Null = never answered.
  Future<DateTime?> getCheckedInFor({
    required String groupId,
    required String userId,
  }) async {
    final row = await _client
        .from('group_members')
        .select('checked_in_for')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();
    final raw = row?['checked_in_for'] as String?;
    return raw == null ? null : DateTime.parse(raw);
  }

  /// Records whether I met up for the meetup at [meetingTime], which hides
  /// the "did it happen?" prompt for it. Doesn't affect my own reliability
  /// score — that comes only from the others' [submitReviews].
  Future<void> checkIn({
    required String groupId,
    required String userId,
    required bool attended,
    required DateTime meetingTime,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('group_members')
        .update({
          'attended': attended,
          'checked_in_for': meetingTime.toUtc().toIso8601String(),
        })
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Anonymous reviews of the other participants after a meetup. The
  /// database recomputes each reviewee's reliability score from them.
  Future<void> submitReviews({
    required String groupId,
    required String reviewerId,
    required DateTime meetingTime,
    required List<MeetupReview> reviews,
  }) async {
    if (reviews.isEmpty) return;
    await SupabaseService.ensureFreshSession();
    await _client
        .from('meetup_reviews')
        .upsert(
          reviews
              .map(
                (r) => r.toMap(
                  groupId: groupId,
                  reviewerId: reviewerId,
                  meetingTime: meetingTime,
                ),
              )
              .toList(),
        );
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
