import 'supabase_service.dart';

class ReportService {
  final _client = SupabaseService.client;

  Future<void> submitReport({
    required String reporterId,
    required String reportedUserId,
    String? groupId,
    required String reason,
    String? details,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('reports').insert({
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'group_id': groupId,
      'reason': reason,
      'details': details,
    });
  }
}
