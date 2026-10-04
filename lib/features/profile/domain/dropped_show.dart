import 'package:flutter/foundation.dart';

/// Standardized taxonomies for why a user abandoned a show (Feature Spec 03 §3.2).
abstract class DropReasonTaxonomy {
  static const String pacingSlowed = 'Pacing slowed down / Boring';
  static const String jumpedShark = 'Writing jumped the shark';
  static const String charactersDied = 'Loved characters died or left';
  static const String tooDepressing = 'Too depressing / grimdark';
  static const String timeCommitment = 'Too many seasons / Time commitment';
  static const String betterOptions = 'Better options on my watchlist';

  static const List<String> allReasons = [
    jumpedShark,
    pacingSlowed,
    charactersDied,
    tooDepressing,
    timeCommitment,
    betterOptions,
  ];

  /// `drop_reason_enum` values (TA-02) for each taxonomy label.
  static const dbValues = {
    pacingSlowed: 'PACING_SLOWED',
    jumpedShark: 'WRITING_JUMPED_SHARK',
    charactersDied: 'CAST_DEPARTURE',
    tooDepressing: 'TOO_DARK_DEPRESSING',
    timeCommitment: 'TIME_COMMITMENT',
    betterOptions: 'BETTER_OPTIONS',
  };

  static String toDbValue(String label) => dbValues[label] ?? 'BETTER_OPTIONS';

  static String? fromDbValue(String? value) {
    for (final MapEntry(:key, value: db) in dbValues.entries) {
      if (db == value) return key;
    }
    return null;
  }

  static String getReasonIcon(String reason) {
    switch (reason) {
      case jumpedShark:
        return '📉';
      case pacingSlowed:
        return '💤';
      case charactersDied:
        return '💔';
      case tooDepressing:
        return '🌧️';
      case timeCommitment:
        return '⏳';
      case betterOptions:
        return '🍿';
      default:
        return '💀';
    }
  }
}

/// What the "Log Dropped Show" sheet collects (FE-608); the Graveyard controller turns it
/// into a `user_dropped_shows` row.
@immutable
class DropDetails {
  final int season;
  final int? episode;
  final String reason;
  final bool willingToRevisit;
  final bool notifyOnAcclaim;
  final String? notes;

  const DropDetails({
    this.season = 1,
    this.episode = 1,
    this.reason = DropReasonTaxonomy.jumpedShark,
    this.willingToRevisit = false,
    this.notifyOnAcclaim = false,
    this.notes,
  });

  DropDetails copyWith({
    int? season,
    int? episode,
    String? reason,
    bool? willingToRevisit,
    bool? notifyOnAcclaim,
    String? notes,
  }) =>
      DropDetails(
        season: season ?? this.season,
        episode: episode ?? this.episode,
        reason: reason ?? this.reason,
        willingToRevisit: willingToRevisit ?? this.willingToRevisit,
        notifyOnAcclaim: notifyOnAcclaim ?? this.notifyOnAcclaim,
        notes: notes ?? this.notes,
      );
}

/// An entry in the user's TV Graveyard (SCR-18, FE-307).
@immutable
class DroppedShow {
  final String id;
  final String userId;
  final int titleId;
  final String mediaType;
  final String title;
  final String? posterUrl;
  final int releaseYear;
  final int droppedAtSeason;
  final int? droppedAtEpisode;
  final String reason;
  final bool willingToRevisit;
  final String? notes;
  final bool notifyOnAcclaim;
  final DateTime createdAt;

  const DroppedShow({
    required this.id,
    required this.userId,
    required this.titleId,
    this.mediaType = 'tv',
    required this.title,
    this.posterUrl,
    required this.releaseYear,
    required this.droppedAtSeason,
    this.droppedAtEpisode,
    required this.reason,
    this.willingToRevisit = false,
    this.notes,
    this.notifyOnAcclaim = false,
    required this.createdAt,
  });

  String get milestoneText {
    if (droppedAtEpisode != null) {
      return 'Season $droppedAtSeason, Episode $droppedAtEpisode';
    }
    return 'Season $droppedAtSeason';
  }

  DroppedShow copyWith({
    bool? willingToRevisit,
    bool? notifyOnAcclaim,
    String? notes,
  }) {
    return DroppedShow(
      id: id,
      userId: userId,
      titleId: titleId,
      mediaType: mediaType,
      title: title,
      posterUrl: posterUrl,
      releaseYear: releaseYear,
      droppedAtSeason: droppedAtSeason,
      droppedAtEpisode: droppedAtEpisode,
      reason: reason,
      willingToRevisit: willingToRevisit ?? this.willingToRevisit,
      notes: notes ?? this.notes,
      notifyOnAcclaim: notifyOnAcclaim ?? this.notifyOnAcclaim,
      createdAt: createdAt,
    );
  }
}
