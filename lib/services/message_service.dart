import '../models/message.dart';
import 'supabase_service.dart';

class MessageService {
  final _client = SupabaseService.client;

  Stream<List<ChatMessage>> streamMessages(String groupId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at')
        .map((rows) => rows.map((m) => ChatMessage.fromMap(m)).toList());
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String content,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('messages').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'content': content,
    });
  }
}
