import 'supabase_service.dart';
import '../models/buddy.dart';

class LikeService {
  final _client = SupabaseService.client;

  /// Records that the current user liked [toUser] and reports whether
  /// [toUser] had already liked them back — a mutual match. Runs through a
  /// security-definer function so the client never gets read access to who
  /// has liked it (see get_buddies/blocked_user_ids for why).
  Future<bool> like({required String toUser, String? activityId}) async {
    await SupabaseService.ensureFreshSession();
    final result = await _client.rpc(
      'like_user',
      params: {'target': toUser, 'target_activity': activityId},
    );
    return result as bool;
  }

  /// Undoes a like sent by mistake (swipe "rewind") — a no-op if the other
  /// side has already liked back, since that's a completed match and can't
  /// be silently undone.
  Future<void> unlike(String toUser) async {
    await SupabaseService.ensureFreshSession();
    await _client.rpc('unlike_user', params: {'target': toUser});
  }

  /// Everyone the current user has already liked for [activityId] — used to
  /// keep a decided candidate (whether or not it's mutual yet) from
  /// reappearing as a match suggestion for that same activity.
  Future<Set<String>> likedUserIdsForActivity(String activityId) async {
    final rows = await _client
        .from('likes')
        .select('to_user')
        .eq('from_user', SupabaseService.currentUserId as String)
        .eq('activity_id', activityId);
    return (rows as List).map((r) => r['to_user'] as String).toSet();
  }

  /// Who liked me and is still waiting for my answer (see migration 0054).
  /// Empty if that function isn't there yet.
  Future<List<ReceivedLike>> getLikesReceived() async {
    try {
      final rows = await _client.rpc('get_likes_received');
      return (rows as List)
          .map(
            (row) => ReceivedLike(
              userId: row['liker_id'] as String,
              likedAt: DateTime.parse(row['liked_at'] as String),
              activityId: row['activity_id'] as String?,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Everyone the current user has mutually liked — a "Sportbuddy"
  /// connection — newest first. A mutual pair "connects" at whichever of the
  /// two likes came second.
  Future<List<Buddy>> getBuddies() async {
    final rows = await _client.rpc('get_buddies');
    return (rows as List)
        .map(
          (row) => Buddy(
            userId: row['buddy_id'] as String,
            connectedAt: DateTime.parse(row['connected_at'] as String),
            activityId: row['activity_id'] as String?,
          ),
        )
        .toList();
  }
}
