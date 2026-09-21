import '../models/profile.dart';
import 'profile_service.dart';
import 'supabase_service.dart';

class BlockService {
  final _client = SupabaseService.client;
  final _profileService = ProfileService();

  /// Blocks [userId] and immediately leaves any group chat I currently share
  /// with them, so blocking actually ends the conversation instead of just
  /// filtering future matches (see 0027_block_user_leaves_chats.sql).
  Future<void> blockUser(String userId) async {
    await SupabaseService.ensureFreshSession();
    await _client.rpc('block_user', params: {'target': userId});
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
