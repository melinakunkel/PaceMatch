import '../models/message.dart';
import 'group_service.dart';
import 'supabase_service.dart';

class MessageService {
  final _client = SupabaseService.client;

  Stream<List<ChatMessage>> streamMessages(String groupId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((m) => ChatMessage.fromMap(m)).toList());
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String content,
    String? gifUrl,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('messages').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'content': content,
      'gif_url': ?gifUrl,
    });
    // Don't count my own message as unread for me.
    await GroupService().markGroupRead(groupId: groupId, userId: senderId);
  }
}
