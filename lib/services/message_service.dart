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

  /// Everyone's reactions in this chat, live.
  Stream<List<MessageReaction>> streamReactions(String groupId) {
    return _client
        .from('message_reactions')
        .stream(primaryKey: ['message_id', 'user_id'])
        .eq('group_id', groupId)
        .map((rows) => rows.map(MessageReaction.fromMap).toList());
  }

  /// Sets my reaction (replacing an earlier one), or removes it when
  /// [emoji] is null.
  Future<void> setReaction({
    required String messageId,
    required String groupId,
    required String userId,
    String? emoji,
  }) async {
    await SupabaseService.ensureFreshSession();
    if (emoji == null) {
      await _client
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId);
      return;
    }
    await _client.from('message_reactions').upsert({
      'message_id': messageId,
      'group_id': groupId,
      'user_id': userId,
      'emoji': emoji,
    }, onConflict: 'message_id,user_id');
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String content,
    String? gifUrl,
    String? replyTo,
  }) async {
    await SupabaseService.ensureFreshSession();
    await _client.from('messages').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'content': content,
      'gif_url': ?gifUrl,
      'reply_to': ?replyTo,
    });
    // Don't count my own message as unread for me.
    await GroupService().markGroupRead(groupId: groupId, userId: senderId);
  }
}
