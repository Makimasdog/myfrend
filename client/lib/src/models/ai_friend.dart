class AiFriend {
  final String id;
  final String ownerId;
  final String name;
  final String gender;
  final String? ageRange;
  final String? personality;
  final String? avatarUrl;
  final String? voiceType;
  final String? systemPrompt;
  final Map<String, dynamic>? extraConfig;
  final bool isActive;
  final String? createdAt;

  AiFriend({
    required this.id,
    required this.ownerId,
    required this.name,
    this.gender = 'other',
    this.ageRange,
    this.personality,
    this.avatarUrl,
    this.voiceType,
    this.systemPrompt,
    this.extraConfig,
    this.isActive = true,
    this.createdAt,
  });

  factory AiFriend.fromJson(Map<String, dynamic> json) {
    return AiFriend(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      name: json['name'] as String,
      gender: json['gender'] as String? ?? 'other',
      ageRange: json['age_range'] as String?,
      personality: json['personality'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      voiceType: json['voice_type'] as String?,
      systemPrompt: json['system_prompt'] as String?,
      extraConfig: json['extra_config'] is Map
          ? json['extra_config'] as Map<String, dynamic>
          : null,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'gender': gender,
        'age_range': ageRange,
        'personality': personality,
        'avatar_url': avatarUrl,
        'voice_type': voiceType,
        'system_prompt': systemPrompt,
        'extra_config': extraConfig,
        'is_active': isActive ? 1 : 0,
      };
}
