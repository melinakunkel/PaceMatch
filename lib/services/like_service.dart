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
