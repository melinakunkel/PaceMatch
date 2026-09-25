import '../models/admin_items.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

/// In-app feedback from users, plus the admin's read access to feedback,
/// reports and account (pause/delete) reasons — see
/// 0046_admin_feedback.sql. Only admins can read; RLS enforces it.
class FeedbackService {
  final _client = SupabaseService.client;

  Future<void> sendFeedback({
    required FeedbackCategory category,
    required String message,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('feedback').insert({
      'user_id': SupabaseService.currentUserId,
      'category': category.name,
      'message': message.trim(),
    });
  }

  Future<List<FeedbackItem>> getFeedback() async {
    final rows = await _client
        .from('feedback')
        .select('*, profiles(full_name)')
        .order('created_at', ascending: false)
        .limit(500);
    return rows.map(FeedbackItem.fromMap).toList();
  }

  Future<List<ReportItem>> getReports() async {
    final rows = await _client
        .from('reports')
        .select(
          '*, reporter:profiles!reports_reporter_id_fkey(full_name), '
          'reported:profiles!reports_reported_user_id_fkey(full_name, report_count, is_suspended)',
        )
        .order('created_at', ascending: false)
        .limit(500);
    return rows.map(ReportItem.fromMap).toList();
  }

  Future<List<AccountFeedbackItem>> getAccountFeedback() async {
    final rows = await _client
        .from('account_feedback')
        .select()
        .order('created_at', ascending: false)
        .limit(500);
    // No foreign key (the row outlives a deleted account) — look up the
    // names that still exist.
    final ids = rows.map((r) => r['user_id'] as String).toSet().toList();
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ids);
      for (final p in profiles) {
        names[p['id'] as String] = p['full_name'] as String;
      }
    }
    return rows
        .map((r) => AccountFeedbackItem.fromMap(r, names[r['user_id']]))
        .toList();
  }

  Future<void> setStatus({
    required String table,
    required String id,
    required bool done,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client
        .from(table)
        .update({'status': done ? 'done' : 'new'})
        .eq('id', id);
  }

  /// Everyone who is currently an admin.
  Future<List<Profile>> getAdmins() async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('is_admin', true)
        .order('full_name', ascending: true);
    return rows.map(Profile.fromMap).toList();
  }

  /// People to pick a new admin from, by name.
  Future<List<Profile>> searchProfiles(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final rows = await _client
        .from('profiles')
        .select()
        .ilike('full_name', '%$q%')
        .eq('is_admin', false)
        .limit(20);
    return rows.map(Profile.fromMap).toList();
  }

  /// Appoint or remove an admin — only works for admins (checked in the
  /// database), and never removes the last one.
  Future<void> setAdmin(String userId, bool admin) async {
    await SupabaseService.ensureFreshSession();
    await _client.rpc(
      'set_admin',
      params: {'target': userId, 'make_admin': admin},
    );
  }
}
