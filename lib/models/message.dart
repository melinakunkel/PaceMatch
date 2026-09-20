class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as String,
    groupId: map['group_id'] as String,
    senderId: map['sender_id'] as String,
    content: map['content'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
