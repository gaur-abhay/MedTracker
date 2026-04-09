enum UserRole { user, guardian }

class UserProfile {
  final String userId;
  final String username;
  final UserRole role;

  UserProfile({
    required this.userId,
    required this.username,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'role': role.name,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['userId'] as String,
        username: json['username'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UserRole.user,
        ),
      );
}
