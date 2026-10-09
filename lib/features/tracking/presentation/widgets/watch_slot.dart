import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../domain/tracking_item.dart';
import '../../domain/tracking_models.dart';

/// The first quick action on the title page (SCR-08 §T.2). [item] is null while untracked.
class WatchSlot extends StatelessWidget {
  const WatchSlot({super.key, required this.item, required this.onTap});

  final TrackingItem? item;
  final VoidCallback onTap;

  static const _onLime = Color(0xFF08090C);

  @override
  Widget build(BuildContext context) {
    final tracked = item;
    final (icon, label, filled) = tracked == null
        ? (Icons.play_circle_outline_rounded, 'Start watching', false)
        : switch (tracked.state) {
            TrackingState.watching => (Icons.play_circle_filled_rounded, 'Watching', true),
            TrackingState.caughtUp => (Icons.check_circle_rounded, 'Up to date', true),
            TrackingState.finished => (Icons.check_circle_rounded, 'Finished', true),
          };
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            key: const Key('title_watch_action'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: filled ? TellyColors.phosphorLime : TellyColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: filled ? TellyColors.phosphorLime : TellyColors.borderGlassOf(context)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: filled ? _onLime : TellyColors.primaryAccentOf(context)),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.caption(color: filled ? _onLime : TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
