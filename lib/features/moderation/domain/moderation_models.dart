library moderation_models;

/// Reasons for reporting user content conforming to Apple Guideline 1.2 and Spec 05.
enum ContentReportReason {
  unmarkedSpoiler(
    label: 'Major Unmarked Spoilers',
    description: 'Reveals major plot twist or character fate without spoiler mask',
  ),
  harassment(
    label: 'Harassment / Hate Speech',
    description: 'Attacks, threatens, or insults other users',
  ),
  spam(
    label: 'Spam / Commercial Promotion',
    description: 'Selling accounts, links, or bot activity',
  ),
  inaccurateMetadata(
    label: 'Inaccurate Metadata',
    description: 'Incorrect season episode count, title typo, or wrong cast',
  );

  final String label;
  final String description;

  const ContentReportReason({required this.label, required this.description});
}

/// Model representing a filed content report.
class ContentReport {
  final String id;
  final String targetContentId;
  final String targetContentType; // 'review', 'comment', 'ranking'
  final String authorUsername;
  final String titleName;
  final ContentReportReason reason;
  final String details;
  final DateTime createdAt;
  final bool mutedAuthor;
  final bool blockedAuthor;
  final bool mutedTitle;

  const ContentReport({
    required this.id,
    required this.targetContentId,
    required this.targetContentType,
    required this.authorUsername,
    required this.titleName,
    required this.reason,
    required this.details,
    required this.createdAt,
    this.mutedAuthor = false,
    this.blockedAuthor = false,
    this.mutedTitle = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'target_content_id': targetContentId,
        'target_content_type': targetContentType,
        'author_username': authorUsername,
        'title_name': titleName,
        'reason': reason.name,
        'details': details,
        'created_at': createdAt.toIso8601String(),
        'muted_author': mutedAuthor,
        'blocked_author': blockedAuthor,
        'muted_title': mutedTitle,
      };
}

/// Model representing a proactively muted title to prevent spoilers.
class MutedTitle {
  final int tmdbId;
  final String title;
  final String mediaType;
  final DateTime mutedAt;

  const MutedTitle({
    required this.tmdbId,
    required this.title,
    this.mediaType = 'tv',
    required this.mutedAt,
  });
}

