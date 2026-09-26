class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  /// Set for a GIF message (then [content] is just a "GIF" fallback text).
  final String? gifUrl;

  /// The message this one answers, if any (same chat).
  final String? replyTo;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.gifUrl,
    this.replyTo,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as String,
    groupId: map['group_id'] as String,
    senderId: map['sender_id'] as String,
    content: map['content'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    gifUrl: map['gif_url'] as String?,
    replyTo: map['reply_to'] as String?,
  );
}

/// One person's emoji on a message.
class MessageReaction {
  const MessageReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  final String messageId;
  final String userId;
  final String emoji;

  factory MessageReaction.fromMap(Map<String, dynamic> map) => MessageReaction(
    messageId: map['message_id'] as String,
    userId: map['user_id'] as String,
    emoji: map['emoji'] as String,
  );
}
