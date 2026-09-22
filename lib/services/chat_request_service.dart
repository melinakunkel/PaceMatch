import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// A pending row IS the request — see chat_requests in
/// 0029_discover_visibility_and_chat_requests.sql for why there's no status
/// column: accepting deletes the row and creates the group chat (client
/// side, same as the existing direct-contact flow), declining just deletes
/// it so the sender can try again later.
class ChatRequestService {
  final _client = SupabaseService.client;

  Future<void> sendRequest({
    required String toUser,
    required String activityId,
  }) async {
    await SupabaseService.ensureFreshSession();
    try {
      await _client.from('chat_requests').insert({
        'from_user': SupabaseService.currentUserId,
        'to_user': toUser,
        'activity_id': activityId,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation: already requested, nothing to do.
      if (e.code != '23505') rethrow;
    }
  }

  /// Activity ids I've already sent a request for — used by the Discover
  /// screen to show "Anfrage gesendet" instead of the button again.
  Future<Set<String>> sentActivityIds() async {
    final rows = await _client
        .from('chat_requests')
        .select('activity_id')
        .eq('from_user', SupabaseService.currentUserId as String);
    return (rows as List).map((r) => r['activity_id'] as String).toSet();
  }

  /// Requests addressed to me, newest first.
  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final rows = await _client
        .from('chat_requests')
        .select('from_user, activity_id, created_at')
        .eq('to_user', SupabaseService.currentUserId as String)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Accepting still needs the caller to create/join the group chat — this
  /// just clears the request so it stops showing up as pending.
  Future<void> respond({
    required String fromUser,
    required String activityId,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('chat_requests')
        .delete()
        .eq('from_user', fromUser)
        .eq('to_user', SupabaseService.currentUserId as String)
        .eq('activity_id', activityId);
  }
}
