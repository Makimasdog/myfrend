class ChatSession {
  final String id;
  final String userId;
  final String friendId;
  final String friendType; // 'ai' or 'human'
  final String? title;
  final String? lastMessage;
  final String? lastMessageAt;
  final String? friendName;
  final String? friendAvatar;
  final String? createdAt;

  ChatSession({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendType,
    this.title,
    this.lastMessage,
    this.lastMessageAt,
    this.friendName,
    this.friendAvatar,
    this.createdAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      friendId: json['friend_id'] as String,
      friendType: json['friend_type'] as String,
      title: json['title'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
      friendName: json['friend_name'] as String?,
      friendAvatar: json['friend_avatar'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
