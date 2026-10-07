/// A row of `public.users` (Spec 02 §2.2). A freshly signed-up user has no
/// [username] until the handle is reserved (FE-107).
class UserProfile {
  final String id;
  final String? username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String visibilityMode;

  /// Medal posts in the feed (features/10 §10); unlocks happen either way.
  final bool shareAchievements;
  final bool onboardingCompleted;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.visibilityMode = 'PUBLIC',
    this.shareAchievements = true,
    this.onboardingCompleted = false,
    required this.createdAt,
  });

  bool get hasHandle => username != null && username!.isNotEmpty;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        username: json['username'] as String?,
        displayName: (json['display_name'] as String?) ?? '',
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        visibilityMode: (json['visibility_mode'] as String?) ?? 'PUBLIC',
        shareAchievements: (json['share_achievements'] as bool?) ?? true,
        onboardingCompleted: (json['onboarding_completed'] as bool?) ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? visibilityMode,
    bool? shareAchievements,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      visibilityMode: visibilityMode ?? this.visibilityMode,
      shareAchievements: shareAchievements ?? this.shareAchievements,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt,
    );
  }
}
