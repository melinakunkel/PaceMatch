import 'package:supabase_flutter/supabase_flutter.dart';

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
}
