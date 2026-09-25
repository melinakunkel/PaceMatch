import '../models/admin_items.dart';
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
}
