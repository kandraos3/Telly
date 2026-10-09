import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../domain/tracking_models.dart';
import 'tracking_labels.dart';

enum EpisodeAction { unlog, rewatched, jump }

/// What the episode sheet shows and offers (features/11 §4.3, §4.4).
class EpisodeSheet extends ConsumerWidget {
  const EpisodeSheet({
    super.key,
    required this.episode,
    required this.watched,
    required this.aired,
    required this.now,
    this.jumpCount = 0,
    this.footer,
  });

  final EpisodeInfo episode;

  /// The episode is at or before the place.
  final bool watched;

  /// The episode has aired; one that hasn't can't be marked watched.
  final bool aired;
  final DateTime now;

  /// How many episodes *Watched up to here* marks, when more than one.
  final int jumpCount;

  /// Reserved for #216 (episode ratings and comments).
  final Widget? footer;

  static Future<EpisodeAction?> show(
    BuildContext context, {
    required EpisodeInfo episode,
    required bool watched,
    required bool aired,
    required DateTime now,
    int jumpCount = 0,
    Widget? footer,
  }) {
    return TellyFrostedSheet.show<EpisodeAction>(
      context: context,
      builder: (_) => EpisodeSheet(
        episode: episode,
        watched: watched,
        aired: aired,
        now: now,
        jumpCount: jumpCount,
        footer: footer,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final still = TmdbImages.backdrop(episode.stillPath, size: 'w500');
    final network = ref.watch(posterNetworkImagesProvider);
    final name = episode.name == null || episode.name!.isEmpty ? 'Episode ${episode.episode}' : episode.name!;
    final air = episode.airDate == null
        ? null
        : '${aired ? 'Aired' : 'Airs'} ${TrackingLabels.date(episode.airDate!, now)}';
    return Column(
      key: const Key('episode_sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: still != null && network
                ? Image.network(still, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _stillFallback(context))
                : _stillFallback(context),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${episode.ref.label} · $name',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800),
        ),
        if (air != null || watched)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              [if (air != null) air, if (watched) 'Watched'].join(' · '),
              style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
            ),
          ),
        if (episode.overview != null && episode.overview!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            episode.overview!,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)).copyWith(height: 1.4),
          ),
        ],
        const SizedBox(height: 16),
        if (watched) ...[
          TellyPrimaryButton(
            key: const Key('episode_unlog_button'),
            label: '↩ Mark as not watched',
            onPressed: () => Navigator.of(context).pop(EpisodeAction.unlog),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('episode_rewatched_button'),
            onPressed: () => Navigator.of(context).pop(EpisodeAction.rewatched),
            child: const Text('Rewatched it'),
          ),
        ] else if (aired) ...[
          TellyPrimaryButton(
            key: const Key('episode_jump_button'),
            label: '✓ Watched up to here',
            onPressed: () => Navigator.of(context).pop(EpisodeAction.jump),
          ),
          if (jumpCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Marks $jumpCount episodes watched.',
                key: const Key('episode_jump_count'),
                style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
              ),
            ),
        ] else
          Text(
            "It hasn't aired yet.",
            style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
          ),
        if (footer != null) ...[const SizedBox(height: 12), footer!],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _stillFallback(BuildContext context) => ColoredBox(
        color: TellyColors.cardOf(context),
        child: Center(
          child: Text('E${episode.episode}', style: TellyTypography.titleMedium(color: TellyColors.textTertiaryOf(context))),
        ),
      );
}
