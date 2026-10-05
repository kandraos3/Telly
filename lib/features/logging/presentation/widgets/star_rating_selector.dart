import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';

/// Five stars with half-star precision (FE-LOG-02). Tapping the left half of a star picks
/// `n - 0.5`, the right half picks `n`; dragging across the row scrubs the value. Exposed to
/// assistive tech as an adjustable control stepping by half a star.
class StarRatingSelector extends StatelessWidget {
  static const starCount = 5;

  final double? value;
  final ValueChanged<double> onChanged;
  final double starSize;

  const StarRatingSelector({super.key, required this.value, required this.onChanged, this.starSize = 44});

  double _valueAt(double dx) {
    final raw = (dx / starSize).clamp(0.0, starCount.toDouble());
    // Round up to the half star under the finger, never below half a star.
    return ((raw * 2).ceil() / 2).clamp(0.5, starCount.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final current = value ?? 0;
    return Semantics(
      label: 'Star rating',
      value: value == null ? 'Not rated' : '${_format(current)} of 5 stars',
      increasedValue: '${_format((current + 0.5).clamp(0.5, 5.0))} of 5 stars',
      decreasedValue: '${_format((current - 0.5).clamp(0.5, 5.0))} of 5 stars',
      onIncrease: () => onChanged((current + 0.5).clamp(0.5, 5.0)),
      onDecrease: () => onChanged((current - 0.5).clamp(0.5, 5.0)),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onChanged(_valueAt(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => onChanged(_valueAt(d.localPosition.dx)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= starCount; i++)
                SizedBox.square(
                  key: Key('star_$i'),
                  dimension: starSize,
                  child: Icon(
                    current >= i
                        ? Icons.star_rounded
                        : current >= i - 0.5
                            ? Icons.star_half_rounded
                            : Icons.star_outline_rounded,
                    size: starSize * 0.86,
                    color: current >= i - 0.5 ? TellyColors.warmAmber : TellyColors.strokeStrong,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
