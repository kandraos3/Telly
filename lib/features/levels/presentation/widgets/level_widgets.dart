import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../../achievements/domain/medal.dart';

/// The level ring (`SCR-27`, mockup B1): primary-accent progress around the level number.
class LevelRing extends StatelessWidget {
  final int level;
  final double fraction;
  final double size;
  const LevelRing({super.key, required this.level, required this.fraction, this.size = 84});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Level $level, ${(fraction * 100).round()}% of the way to level ${level + 1}',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: fraction,
            color: TellyColors.primaryAccentOf(context),
            track: TellyColors.strokeOf(context),
          ),
          child: Center(
            child: Text('$level',
                style: TellyTypography.titleLarge(color: TellyColors.textPrimaryOf(context))
                    .copyWith(fontSize: size * 0.34, fontWeight: FontWeight.w800, height: 1)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;
  _RingPainter({required this.fraction, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (fraction > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false,
          base..color = color..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color || old.track != track;
}

/// The 7-week strip (§3, mockup B1): counted weeks filled, a used freeze as ❄, missed weeks
/// outlined, and the running week as "Now".
class StreakStrip extends StatelessWidget {
  final List<StreakWeek> weeks;
  const StreakStrip({super.key, required this.weeks});

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < weeks.length; i++)
          _cell(context, weeks[i], last: i == weeks.length - 1, accent: accent),
      ],
    );
  }

  Widget _cell(BuildContext context, StreakWeek w, {required bool last, required Color accent}) {
    final label = last ? 'Now' : 'W${w.label.split('W').last}';
    final status = switch (w.status) {
      StreakWeekStatus.counted => 'counted',
      StreakWeekStatus.frozen => 'frozen',
      StreakWeekStatus.missed => 'missed',
      StreakWeekStatus.current => 'in progress',
    };
    final (Color? fill, Color border, Widget? child) = switch (w.status) {
      StreakWeekStatus.counted => (accent, accent, const Icon(Icons.check_rounded, size: 18, color: TellyColors.backgroundPrimary)),
      StreakWeekStatus.frozen => (TellyColors.electricCyanOf(context).withValues(alpha: 0.16),
          TellyColors.electricCyanOf(context), const Text('❄', style: TextStyle(fontSize: 15))),
      StreakWeekStatus.missed => (null, TellyColors.strokeOf(context), null),
      StreakWeekStatus.current => (null, accent.withValues(alpha: 0.6), null),
    };
    return Semantics(
      label: '${last ? 'This week' : 'Week ${w.label}'}, $status',
      excludeSemantics: true,
      child: Column(
        key: Key('streak_week_${w.label}'),
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: w.status == StreakWeekStatus.current ? 1.5 : 1),
            ),
            child: Center(child: child),
          ),
          const SizedBox(height: 4),
          Text(label, style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

/// How XP is earned (§6), in plain words: the `SCR-27` "?" sheet and the Rewards screen.
class XpRulesTable extends StatelessWidget {
  const XpRulesTable({super.key});

  static const rows = [
    ('Rank a title (max 10 a week)', '+10'),
    ('Finish a weekly quest', '+40–60'),
    ('Rank at least once in a week', '+25'),
    ('Unlock a medal', '+25'),
    ('Complete a collection', '+100'),
    ('Finish a challenge (squad +100)', '+150'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('xp_rules'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TellySectionHeader(label: 'How you earn XP', padding: EdgeInsets.zero),
        const SizedBox(height: 8),
        for (final (what, xp) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(what, style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)))),
                Text(xp,
                    style: TellyTypography.bodyMedium(color: TellyColors.primaryAccentOf(context))
                        .copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          "Only titles you place through duels count, so imports and re-ranking don't earn XP. "
          'XP never runs out and is never spent; rewards are cosmetic.',
          style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
        ),
      ],
    );
  }
}
