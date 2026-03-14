class Profile {
  const Profile({
    required this.id,
    required this.nickname,
    required this.age,
    this.avatarUrl,
  });

  final String id;
  final String nickname;
  final int age;
  final String? avatarUrl;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      age: (json['age'] as num).toInt(),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'age': age,
      'avatar_url': avatarUrl,
    };
  }
}
