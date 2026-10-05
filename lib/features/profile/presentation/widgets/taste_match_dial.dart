import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/cowatch/domain/spearman_taste_match_calculator.dart';

/// Radial animated Taste Match Dial with Phosphor Lime glow.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §15 (`SCR-15`).
class TasteMatchDial extends StatefulWidget {
  final int matchPercentage;
  final int mutualTitleCount;
  final TasteAffinityTier affinityTier;
  final double size;
  final bool animate;

  const TasteMatchDial({
    super.key,
    required this.matchPercentage,
    required this.mutualTitleCount,
    required this.affinityTier,
    this.size = 180,
    this.animate = true,
  });

  @override
  State<TasteMatchDial> createState() => _TasteMatchDialState();
}

class _TasteMatchDialState extends State<TasteMatchDial> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final targetProgress = widget.matchPercentage / 100.0;
    _progressAnimation = Tween<double>(begin: 0.0, end: targetProgress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant TasteMatchDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchPercentage != widget.matchPercentage) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final currentPct = (_progressAnimation.value * 100).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _DialPainter(
                      progress: _progressAnimation.value,
                      glowColor: TellyColors.phosphorLime,
                      trackColor: TellyColors.strokeSubtleOf(context),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$currentPct',
                            style: TellyTypography.displayXXL(
                              color: TellyColors.textPrimaryOf(context),
                            ).copyWith(
                              fontSize: widget.size * 0.28,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            '%',
                            style: TellyTypography.labelLarge(
                              color: TellyColors.phosphorLime,
                            ).copyWith(
                              fontSize: widget.size * 0.12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TASTE MATCH',
                        style: TellyTypography.caption(
                          color: TellyColors.textTertiaryOf(context),
                        ).copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: TellyColors.phosphorLime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: TellyColors.phosphorLime.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.affinityTier.label,
                          style: TellyTypography.caption(
                            color: TellyColors.phosphorLime,
                          ).copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Based on ${widget.mutualTitleCount} mutual titles ranked',
              style: TellyTypography.caption(
                color: TellyColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color glowColor;
  final Color trackColor;

  _DialPainter({
    required this.progress,
    required this.glowColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.001) return;

    // Outer glow for Phosphor Lime
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Active arc progress
    final activePaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: [
          TellyColors.electricViolet,
          glowColor,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.trackColor != trackColor;
  }
}
