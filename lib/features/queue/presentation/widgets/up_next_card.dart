import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../domain/streaming_models.dart';

/// SCR-13 "Up next" card (epic #47): the queue's pick on 168 dp art under a dark scrim,
/// then a bar with ▶ Watch (primary) and ✓ Seen. ↻ Another shows when [onShuffle] is set.
/// The art always sits under the dark scrim, so its text colours are fixed in both themes.
class UpNextCard extends StatelessWidget {
  final WatchlistItem item;
  final String providerName;
  final VoidCallback onTap;
  final VoidCallback onWatch;
  final VoidCallback onSeen;

  /// Null hides ↻ Another (a pool of one title).
  final VoidCallback? onShuffle;

  const UpNextCard({
    super.key,
    required this.item,
    required this.providerName,
    required this.onTap,
    required this.onWatch,
    required this.onSeen,
    this.onShuffle,
  });

  static const _eyebrow = TellyColors.phosphorLime;
  static const _titleColor = Colors.white;
  static const _metaColor = Color(0xFFC8CAD8);
  static const _scrim = Color(0xFF08090C);

  String get _meta {
    final parts = <String>[
      providerName,
      if (item.mediaType == 'movie')
        '${item.runtimeMinutes ?? 120} min'
      else
        '${item.seasonCount ?? 1} ${(item.seasonCount ?? 1) == 1 ? 'season' : 'seasons'}',
      if (item.friendsAvgScore > 0) '★ ${item.friendsAvgScore.toStringAsFixed(2)}',
      if (item.savedFromHandle != null) 'saved from ${item.savedFromHandle}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Semantics(
                button: true,
                label: 'Up next: ${item.title}, $_meta',
                excludeSemantics: true,
                child: GestureDetector(
                  key: const Key('queue_up_next_art'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: SizedBox(
                    height: 168,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PosterImage(
                          posterPath: item.posterPath,
                          fallback: Container(color: TellyColors.backgroundCard),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.2, 1.0],
                              colors: [_scrim.withValues(alpha: 0), _scrim.withValues(alpha: 0.92)],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'UP NEXT',
                                    style: TellyTypography.caption(color: _eyebrow)
                                        .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                                  ),
                                  if (item.isLeavingSoon) ...[
                                    const SizedBox(width: 8),
                                    const _LeavingSoonTag(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TellyTypography.titleLarge(color: _titleColor).copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TellyTypography.caption(color: _metaColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // A separate target, outside the art's merged semantics.
              if (onShuffle != null)
                Positioned(top: 4, right: 4, child: UpNextShuffleButton(onPressed: onShuffle!)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('queue_up_next_watch'),
                    onPressed: onWatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TellyColors.phosphorLime,
                      foregroundColor: const Color(0xFF08090C),
                      minimumSize: const Size(0, 48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      'Watch on $providerName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.labelMedium(color: const Color(0xFF08090C)).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const Key('queue_up_next_seen'),
                  onPressed: onSeen,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: TellyColors.cardOf(context),
                    foregroundColor: TellyColors.textPrimaryOf(context),
                    side: BorderSide(color: TellyColors.borderGlassOf(context)),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    '✓ Seen',
                    style: TellyTypography.labelMedium(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ↻ Another: a frosted pill over the card's art, with a 48 dp target.
class UpNextShuffleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const UpNextShuffleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pick another title',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('queue_up_next_shuffle'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF08090C).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('Another', style: TellyTypography.caption(color: Colors.white).copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeavingSoonTag extends StatelessWidget {
  const _LeavingSoonTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: TellyColors.neonCoral.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'LEAVING SOON',
        style: TellyTypography.caption(color: TellyColors.neonCoral).copyWith(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}
