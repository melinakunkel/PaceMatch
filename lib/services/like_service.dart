import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/buddy.dart';
import 'supabase_service.dart';

class LikeService {
  final _client = SupabaseService.client;

  /// Records that [fromUser] liked [toUser] and reports whether [toUser]
  /// had already liked [fromUser] back — a mutual match.
  Future<bool> like({
    required String fromUser,
    required String toUser,
    String? activityId,
  }) async {
    await SupabaseService.ensureFreshSession();
    try {
      await _client.from('likes').insert({
        'from_user': fromUser,
        'to_user': toUser,
        'activity_id': activityId,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation: already liked this person, still worth
      // checking for a mutual match below.
      if (e.code != '23505') rethrow;
    }
    final reverse = await _client
        .from('likes')
        .select('id')
        .eq('from_user', toUser)
        .eq('to_user', fromUser)
        .maybeSingle();
    return reverse != null;
  }

  /// Everyone [userId] has mutually liked — a "Sportbuddy" connection —
  /// newest first. A mutual pair "connects" at whichever of the two likes
  /// came second.
  Future<List<Buddy>> getBuddies(String userId) async {
    final iLiked = await _client
        .from('likes')
        .select('to_user, activity_id, created_at')
        .eq('from_user', userId);
    final likedMe = await _client
        .from('likes')
        .select('from_user, created_at')
        .eq('to_user', userId);
    final likedMeAt = {
      for (final row in likedMe)
        row['from_user'] as String: DateTime.parse(row['created_at'] as String),
    };

    final buddies = <Buddy>[];
    for (final row in iLiked) {
      final otherId = row['to_user'] as String;
      final theirLikeAt = likedMeAt[otherId];
      if (theirLikeAt == null) continue;
      final myLikeAt = DateTime.parse(row['created_at'] as String);
      buddies.add(
        Buddy(
          userId: otherId,
          connectedAt: myLikeAt.isAfter(theirLikeAt) ? myLikeAt : theirLikeAt,
          activityId: row['activity_id'] as String?,
        ),
      );
    }
    buddies.sort((a, b) => b.connectedAt.compareTo(a.connectedAt));
    return buddies;
  }
}
