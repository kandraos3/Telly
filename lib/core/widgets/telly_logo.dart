import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';

/// Brand mark geometry, as fractions of the tile side.
/// Spec: `docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md` §7.1.
abstract class TellyBrand {
  static const String name = 'telly';

  /// Bundled in `pubspec.yaml` under `fonts:` so the painter can lay out text synchronously.
  static const String fontFamily = 'PlusJakartaSans';
  static const FontWeight fontWeight = FontWeight.w800;

  static const double fontSize = 300 / 1024;
  static const double letterSpacing = -14 / 1024;
  static const double baseline = 600 / 1024;
  static const double cornerRadius = 0.224;

  static const List<Color> tileGradient = [TellyColors.strokeSubtle, TellyColors.backgroundSurface];
  static const Alignment tileGradientCenter = Alignment(0, -0.6);
  static const double tileGradientRadius = 0.9;

  /// Wordmark style for a tile (or a text run) of side [tileSize].
  static TextStyle wordmarkStyle(double tileSize, {Color color = TellyColors.phosphorLime}) => TextStyle(
        fontFamily: fontFamily,
        fontWeight: fontWeight,
        fontSize: tileSize * fontSize,
        letterSpacing: tileSize * letterSpacing,
        height: 1,
        color: color,
      );
}

/// The Telly logo: the lime `telly` wordmark on the slate tile, as used for the app icon.
class TellyLogo extends StatelessWidget {
  final double size;

  const TellyLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Telly',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * TellyBrand.cornerRadius),
        child: CustomPaint(size: Size.square(size), painter: const TellyLogoPainter()),
      ),
    );
  }
}

/// The wordmark alone (no tile), for surfaces that are already dark.
class TellyWordmark extends StatelessWidget {
  final double fontSize;

  const TellyWordmark({super.key, this.fontSize = 24});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Telly',
      excludeSemantics: true,
      child: Text(TellyBrand.name, style: TellyBrand.wordmarkStyle(fontSize / TellyBrand.fontSize)),
    );
  }
}

/// Paints the square (unclipped) brand tile. Also renders the platform icon layers:
/// [inset] shrinks the visible tile inside the canvas (1/6 for Android adaptive layers),
/// and either layer can be switched off.
class TellyLogoPainter extends CustomPainter {
  final bool paintTile;
  final bool paintWordmark;
  final Color wordmarkColor;
  final double inset;

  const TellyLogoPainter({
    this.paintTile = true,
    this.paintWordmark = true,
    this.wordmarkColor = TellyColors.phosphorLime,
    this.inset = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final canvasRect = Offset.zero & size;
    final tile = canvasRect.deflate(size.shortestSide * inset);

    if (paintTile) {
      final shader = const RadialGradient(
        center: TellyBrand.tileGradientCenter,
        radius: TellyBrand.tileGradientRadius,
        colors: TellyBrand.tileGradient,
      ).createShader(tile);
      canvas.drawRect(canvasRect, Paint()..shader = shader);
    }

    if (paintWordmark) {
      final text = TextPainter(
        text: TextSpan(text: TellyBrand.name, style: TellyBrand.wordmarkStyle(tile.width, color: wordmarkColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      final baseline = text.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      text.paint(
        canvas,
        Offset(tile.center.dx - text.width / 2, tile.top + tile.height * TellyBrand.baseline - baseline),
      );
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(TellyLogoPainter oldDelegate) =>
      oldDelegate.paintTile != paintTile ||
      oldDelegate.paintWordmark != paintWordmark ||
      oldDelegate.wordmarkColor != wordmarkColor ||
      oldDelegate.inset != inset;
}
