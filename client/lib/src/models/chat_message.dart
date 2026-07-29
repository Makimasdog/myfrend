class ChatMessage {
  final String id;
  final String sessionId;
  final String senderId;
  final String senderType; // 'user', 'ai', 'human'
  final String content;
  final String contentType; // 'text', 'voice', 'image'
  final String? voiceUrl;
  final bool isRead;
  final String? createdAt;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.senderType,
    required this.content,
    this.contentType = 'text',
    this.voiceUrl,
    this.isRead = false,
    this.createdAt,
  });

  bool get isUserMessage => senderType == 'user';
  bool get isAiMessage => senderType == 'ai';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      senderId: json['sender_id'] as String,
      senderType: json['sender_type'] as String,
      content: json['content'] as String,
      contentType: json['content_type'] as String? ?? 'text',
      voiceUrl: json['voice_url'] as String?,
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: json['created_at'] as String?,
    );
  }
}
