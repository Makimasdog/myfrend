class User {
  final String id;
  final String username;
  final String? nickname;
  final String? avatarUrl;
  final String? gender;
  final String? bio;
  final String? createdAt;

  User({
    required this.id,
    required this.username,
    this.nickname,
    this.avatarUrl,
    this.gender,
    this.bio,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as String?,
      bio: json['bio'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'gender': gender,
        'bio': bio,
        'created_at': createdAt,
      };
}
