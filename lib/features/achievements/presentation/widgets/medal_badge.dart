import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../domain/medal.dart';

enum MedalSize {
  small(40, 45),
  regular(54, 60),
  large(110, 124);

  const MedalSize(this.width, this.height);
  final double width;
  final double height;
}

/// The medal visual (features/10 §9.1): a pointy-top hexagon with the glyph centred.
///
/// Fills are fixed in both themes: gold `#FFE066 → #FFA733` (the God-tier gradient), silver
/// `#E5E7EB → #94A3B8`, bronze `#F5B78A → #B8693A`, special `#A78BFA → #7C5CFF` (white
/// glyph). Locked medals use the Overlay fill, a dashed `strokeSubtle` outline and a
/// `textTertiary` glyph.
class MedalBadge extends StatelessWidget {
  final MedalTier tier;
  final String glyph;
  final bool unlocked;
  final MedalSize size;

  /// Read by screen readers; null excludes the badge (its row already describes it).
  final String? semanticLabel;

  const MedalBadge({
    super.key,
    required this.tier,
    required this.glyph,
    required this.unlocked,
    this.size = MedalSize.regular,
    this.semanticLabel,
  });

  MedalBadge.of(Medal medal, {Key? key, MedalSize size = MedalSize.regular, bool describe = false})
      : this(
          key: key,
          tier: medal.tier,
          glyph: medal.glyph,
          unlocked: medal.isUnlocked,
          size: size,
          semanticLabel: describe ? medal.semanticLabel : null,
        );

  static const _ink = Color(0xFF08090C);

  static (Color, Color) gradientOf(MedalTier tier) => switch (tier) {
        MedalTier.gold => (TellyColors.tierGodStart, TellyColors.tierGodEnd),
        MedalTier.silver => (const Color(0xFFE5E7EB), const Color(0xFF94A3B8)),
        MedalTier.bronze => (const Color(0xFFF5B78A), const Color(0xFFB8693A)),
        MedalTier.special => (TellyColors.tierPrestigeStart, TellyColors.tierPrestigeEnd),
      };

  @override
  Widget build(BuildContext context) {
    final glyphColor = !unlocked
        ? TellyColors.textTertiaryOf(context)
        : tier == MedalTier.special
            ? Colors.white
            : _ink;
    // Shorter glyphs draw larger; four characters still fit inside the hexagon.
    final fontSize = size.width * switch (glyph.characters.length) { <= 1 => 0.42, 2 => 0.34, 3 => 0.27, _ => 0.21 };
    final badge = CustomPaint(
      size: Size(size.width, size.height),
      painter: _HexPainter(
        gradient: unlocked ? gradientOf(tier) : null,
        lockedFill: TellyColors.cardOf(context),
        lockedStroke: TellyColors.strokeSubtleOf(context),
      ),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Center(
          child: Text(
            glyph,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1,
              color: glyphColor,
            ),
          ),
        ),
      ),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: badge)
        : Semantics(label: label, image: true, excludeSemantics: true, child: badge);
  }
}

class _HexPainter extends CustomPainter {
  final (Color, Color)? gradient;
  final Color lockedFill;
  final Color lockedStroke;

  _HexPainter({required this.gradient, required this.lockedFill, required this.lockedStroke});

  static Path hexagon(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w / 2, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final colors = gradient;
    if (colors != null) {
      final paint = Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), [colors.$1, colors.$2]);
      canvas.drawPath(hexagon(size), paint);
      return;
    }
    // Locked: inset by half the stroke so the dashes stay inside the bounds.
    const stroke = 1.5;
    final inset = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final path = hexagon(inset.size).shift(inset.topLeft);
    canvas.drawPath(path, Paint()..color = lockedFill);
    final dash = Paint()
      ..color = lockedStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, (d + 4).clamp(0, metric.length)), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_HexPainter old) =>
      old.gradient != gradient || old.lockedFill != lockedFill || old.lockedStroke != lockedStroke;
}
