class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String visibilityMode;
  final List<String> streamingProviders;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.visibilityMode = 'PUBLIC',
    this.streamingProviders = const [],
    required this.createdAt,
  });

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? visibilityMode,
    List<String>? streamingProviders,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      visibilityMode: visibilityMode ?? this.visibilityMode,
      streamingProviders: streamingProviders ?? this.streamingProviders,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
