import 'supabase_service.dart';

/// Captures why someone paused or deleted their account, for product
/// feedback — see account_feedback in 0031_pause_and_delete_account.sql.
/// Submitted right before the account action itself, so it survives even a
/// deletion (no foreign key ties it to the profile row).
class AccountFeedbackService {
  final _client = SupabaseService.client;

  Future<void> submit({required String action, String? reason}) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('account_feedback').insert({
      'user_id': SupabaseService.currentUserId,
      'action': action,
      'reason': (reason == null || reason.trim().isEmpty)
          ? null
          : reason.trim(),
    });
  }
}
