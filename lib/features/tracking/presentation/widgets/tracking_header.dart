import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../domain/tracking_item.dart';
import 'tracking_labels.dart';

/// "● Watching · S2 · E6 next" above the title (SCR-08 §T.1). Lime for progress, amber for news.
class TrackingEyebrow extends StatelessWidget {
  const TrackingEyebrow({super.key, required this.item});

  final TrackingItem item;

  @override
  Widget build(BuildContext context) {
    final color =
        TrackingLabels.eyebrowIsAmber(item) ? TellyColors.warmAmberOf(context) : TellyColors.primaryAccentOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '● ${TrackingLabels.eyebrow(item).toUpperCase()}',
        key: const Key('tracking_eyebrow'),
        style: TellyTypography.caption(color: color).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
      ),
    );
  }
}

/// The 3 dp line along the backdrop's bottom edge (SCR-08 §T.1): a `strokeSubtle` track with the
/// primary accent filled to [fraction].
class TrackingProgressLine extends StatelessWidget {
  const TrackingProgressLine({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('tracking_progress_line'),
      height: 3,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: TellyColors.strokeSubtleOf(context))),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: TellyColors.primaryAccentOf(context)),
            ),
          ),
        ],
      ),
    );
  }
}
