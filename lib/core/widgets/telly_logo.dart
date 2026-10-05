import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';

/// The Telly logomark: a cathode screen with antennae framing three ascending
/// rank bars. Painted as vector paths so it stays crisp at every density.
class TellyLogo extends StatelessWidget {
  final double size;
  final Color color;

  const TellyLogo({super.key, this.size = 72, this.color = TellyColors.phosphorLime});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Telly logo',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: TellyLogoPainter(color: color),
      ),
    );
  }
}

class TellyLogoPainter extends CustomPainter {
  final Color color;

  const TellyLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    // Antennae meeting at a point above the screen.
    final apex = Offset(s * 0.5, s * 0.24);
    canvas.drawLine(Offset(s * 0.34, s * 0.06), apex, stroke);
    canvas.drawLine(Offset(s * 0.66, s * 0.06), apex, stroke);

    // Screen.
    final screen = RRect.fromRectAndRadius(
      Rect.fromLTRB(s * 0.08, s * 0.28, s * 0.92, s * 0.9),
      Radius.circular(s * 0.16),
    );
    canvas.drawRRect(screen, stroke);

    // Three ascending rank bars.
    final barWidth = s * 0.12;
    final baseline = s * 0.76;
    const heights = [0.14, 0.24, 0.34];
    for (var i = 0; i < heights.length; i++) {
      final left = s * 0.27 + i * (barWidth + s * 0.055);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, baseline - s * heights[i], left + barWidth, baseline),
          Radius.circular(s * 0.03),
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(TellyLogoPainter oldDelegate) => oldDelegate.color != color;
}
