import 'package:flutter/material.dart';

import '../services/haptics_service.dart';
import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// One option of a [TellySegmentedControl].
@immutable
class TellySegment<T> {
  final T value;
  final String label;

  /// Key for the tappable segment (tests and deep finds).
  final Key? key;

  const TellySegment({required this.value, required this.label, this.key});
}

/// Section switcher shared by Feed (Following / Squads / Global), Queue (Watchlist /
/// My Lists / Friends' Lists) and the Squad hub (FE-UI-01).
///
/// A raised Surface track with the selected option lifted onto an Overlay card and its
/// label in the accent colour. The Movies / TV Shows choice uses [TellyCanonSwitcher]
/// instead, so the two levels never look alike.
class TellySegmentedControl<T> extends StatelessWidget {
  final List<TellySegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry margin;

  const TellySegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  /// Accent label colour of the selected segment; the darker lime keeps AA contrast on light.
  static Color selectedLabelColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? const Color(0xFF233B00) : TellyColors.phosphorLime;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(child: _SegmentButton<T>(segment: segment, isSelected: segment.value == selected, onChanged: onChanged)),
        ],
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  final TellySegment<T> segment;
  final bool isSelected;
  final ValueChanged<T> onChanged;

  const _SegmentButton({required this.segment, required this.isSelected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? TellySegmentedControl.selectedLabelColor(context) : TellyColors.textPrimaryOf(context);
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        key: segment.key,
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticsService.selectionClick();
          onChanged(segment.value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? TellyColors.cardOf(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? TellyColors.borderGlassOf(context) : Colors.transparent),
          ),
          alignment: Alignment.center,
          child: Text(
            segment.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TellyTypography.labelMedium(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
