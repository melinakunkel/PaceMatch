import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

class BlockService {
  final _client = SupabaseService.client;
  final _profileService = ProfileService();

  Future<void> blockUser(String userId) async {
    await SupabaseService.ensureFreshSession();
    try {
      await _client.from('blocks').insert({
        'blocker_id': SupabaseService.currentUserId,
        'blocked_id': userId,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation: already blocked, nothing to do.
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', SupabaseService.currentUserId as String)
        .eq('blocked_id', userId);
  }

  /// People I've blocked, for the "manage blocked users" list in Settings.
  Future<List<Profile>> getBlockedProfiles() async {
    final rows = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', SupabaseService.currentUserId as String)
        .order('created_at', ascending: false);
    final ids = rows.map((r) => r['blocked_id'] as String).toList();
    return _profileService.getProfilesByIds(ids);
  }

  /// Everyone mutually excluded from the current user's perspective — people
  /// they blocked plus people who blocked them — via a security-definer
  /// function so the direction is never exposed to the client. Used to filter
  /// match/discovery candidates.
  Future<Set<String>> blockedUserIds() async {
    final rows = await _client.rpc('blocked_user_ids');
    return (rows as List).map((r) => r['user_id'] as String).toSet();
  }
}
