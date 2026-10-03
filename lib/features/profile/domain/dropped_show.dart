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

/// An entry in the user's TV Graveyard (SCR-18, FE-307).
@immutable
class DroppedShow {
  final String id;
  final String userId;
  final int titleId;
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
