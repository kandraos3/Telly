import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';

/// The 26 dp progress ring on a season row (SCR-08 §T.5): a lime arc, or a lime disc with ✓ once
/// the season is watched.
class SeasonRing extends StatelessWidget {
  const SeasonRing({super.key, required this.fraction, required this.done});

  final double fraction;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final lime = TellyColors.primaryAccentOf(context);
    return SizedBox(
      width: 26,
      height: 26,
      child: done
          ? const DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: TellyColors.phosphorLime),
              child: Icon(Icons.check_rounded, size: 16, color: Color(0xFF08090C)),
            )
          : CustomPaint(
              painter: _RingPainter(fraction: fraction, track: TellyColors.strokeSubtleOf(context), fill: lime),
            ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.track, required this.fill});

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * fraction.clamp(0.0, 1.0), false, paint..color = fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.track != track || old.fill != fill;
}

/// How an episode row relates to the place (features/11 §5.3, §5.5).
enum EpisodeMark { watched, here, later }

/// One 44 dp episode row: tick column, "E6", the name, and the spoiler guard (SCR-08 §T.5).
class EpisodeRow extends StatelessWidget {
  const EpisodeRow({
    super.key,
    required this.number,
    required this.name,
    required this.mark,
    required this.onTap,
    this.hidden = false,
    this.showHiddenCaption = false,
  });

  final int number;
  final String name;
  final EpisodeMark mark;
  final VoidCallback onTap;

  /// The name is blurred (sigma 4) until tapped (spoiler guard, features/11 §5.5).
  final bool hidden;

  /// The first hidden row says why.
  final bool showHiddenCaption;

  @override
  Widget build(BuildContext context) {
    final lime = TellyColors.primaryAccentOf(context);
    final tertiary = TellyColors.textTertiaryOf(context);
    final nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w600),
    );
    return Semantics(
      button: true,
      label: hidden ? 'Episode $number, hidden until you get there. Tap to reveal.' : 'Episode $number, $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: mark == EpisodeMark.here
              ? BoxDecoration(color: lime.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8))
              : null,
          child: Row(
            children: [
              SizedBox(
                width: 14,
                child: switch (mark) {
                  EpisodeMark.watched => Icon(Icons.check_rounded, size: 14, color: lime),
                  EpisodeMark.here => Icon(Icons.circle, size: 8, color: lime),
                  EpisodeMark.later => const SizedBox.shrink(),
                },
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text(
                  'E$number',
                  style: TellyTypography.caption(color: tertiary).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hidden)
                      ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: nameText)
                    else
                      nameText,
                    if (mark == EpisodeMark.here)
                      Text("You're here", style: TellyTypography.caption(color: lime).copyWith(fontWeight: FontWeight.w700))
                    else if (showHiddenCaption)
                      Text(
                        'Hidden until you get there. Tap to reveal.',
                        key: const Key('spoiler_caption'),
                        style: TellyTypography.caption(color: tertiary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
