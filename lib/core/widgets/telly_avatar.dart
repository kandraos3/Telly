import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// A person's round avatar: their photo, or the first letter of their name (FE-UI-01).
class TellyAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  /// Draws a ring in the canvas colour, so overlapping avatars stay distinct.
  final bool ringed;

  const TellyAvatar({super.key, required this.name, this.imageUrl, this.radius = 16, this.ringed = false});

  @override
  Widget build(BuildContext context) {
    final initial = name.replaceFirst('@', '').trim();
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: TellyColors.cardOf(context),
      foregroundImage: imageUrl != null && imageUrl!.isNotEmpty ? NetworkImage(imageUrl!) : null,
      onForegroundImageError: imageUrl != null && imageUrl!.isNotEmpty ? (_, __) {} : null,
      child: Text(
        initial.isEmpty ? '?' : initial[0].toUpperCase(),
        style: TellyTypography.caption(color: TellyColors.primaryAccentOf(context))
            .copyWith(fontWeight: FontWeight.w800, fontSize: radius * 0.8),
      ),
    );
    if (!ringed) return avatar;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: TellyColors.canvasOf(context)),
      child: avatar,
    );
  }
}

/// Up to [max] overlapping avatars, then a "+N" chip for the rest (FE-UI-01).
class TellyAvatarStack extends StatelessWidget {
  /// `(name, imageUrl)` pairs, in display order.
  final List<(String, String?)> people;

  /// Total people, which may exceed [people] when only a preview was loaded.
  final int? total;
  final int max;
  final double radius;

  const TellyAvatarStack({super.key, required this.people, this.total, this.max = 4, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    final extra = (total ?? people.length) - shown.length;
    final step = radius * 1.4;
    final count = shown.length + (extra > 0 ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();
    final diameter = (radius + 2) * 2;
    return SizedBox(
      height: diameter,
      width: diameter + step * (count - 1),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: TellyAvatar(name: shown[i].$1, imageUrl: shown[i].$2, radius: radius, ringed: true),
            ),
          if (extra > 0)
            Positioned(
              left: step * shown.length,
              child: Container(
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TellyColors.surfaceOf(context),
                  border: Border.all(color: TellyColors.canvasOf(context), width: 2),
                ),
                child: Text(
                  '+$extra',
                  style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))
                      .copyWith(fontWeight: FontWeight.w800, fontSize: radius * 0.75),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
