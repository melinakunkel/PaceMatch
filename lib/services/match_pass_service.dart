import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Tracks who's been passed on (left-swiped) for a given activity — kept
/// separate from likes so passing can be undone/forgotten independently,
/// and so it only ever affects the swipe queue, never the list view.
class MatchPassService {
  final _client = SupabaseService.client;

  Future<void> recordPass({
    required String targetId,
    required String activityId,
  }) async {
    await SupabaseService.ensureFreshSession();
    try {
      await _client.from('activity_passes').insert({
        'user_id': SupabaseService.currentUserId,
        'target_id': targetId,
        'activity_id': activityId,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation: already passed, nothing to do.
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> removePass({
    required String targetId,
    required String activityId,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('activity_passes')
        .delete()
        .eq('user_id', SupabaseService.currentUserId as String)
        .eq('target_id', targetId)
        .eq('activity_id', activityId);
  }

  Future<Set<String>> passedUserIdsForActivity(String activityId) async {
    final rows = await _client
        .from('activity_passes')
        .select('target_id')
        .eq('user_id', SupabaseService.currentUserId as String)
        .eq('activity_id', activityId);
    return (rows as List).map((r) => r['target_id'] as String).toSet();
  }
}
