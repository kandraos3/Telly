import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';
import 'telly_segmented_control.dart';

/// The Movies / TV Shows selector shared by Canon (SCR-14), Queue (SCR-13), Home
/// (SCR-21) and the Squad hub (SCR-17b) (FE-UI-01). Movies always sits on the left.
///
/// Compact look (component library §5.5, epic #47): a Surface track whose selected half
/// lifts onto Overlay with a glass border; the label stays `textPrimary` and the count
/// takes the accent label colour ("Movies 142"). It sizes to its parent, so a caller can
/// wrap it in [Expanded] to share a row. Callers own haptics and state; the switcher only
/// reports `'movie'` or `'tv'`.
class TellyCanonSwitcher extends StatelessWidget {
  /// `'movie'` or `'tv'`.
  final String selected;
  final ValueChanged<String> onSelect;
  final int? movieCount;
  final int? seriesCount;
  final Key? movieKey;
  final Key? seriesKey;
  final EdgeInsetsGeometry margin;

  const TellyCanonSwitcher({
    super.key,
    required this.selected,
    required this.onSelect,
    this.movieCount,
    this.seriesCount,
    this.movieKey,
    this.seriesKey,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CanonOption(
              key: movieKey,
              inset: const EdgeInsets.fromLTRB(4, 4, 2, 4),
              name: 'Movies',
              count: movieCount,
              isSelected: selected == 'movie',
              onTap: () => onSelect('movie'),
            ),
          ),
          Expanded(
            child: _CanonOption(
              key: seriesKey,
              inset: const EdgeInsets.fromLTRB(2, 4, 4, 4),
              name: 'TV Shows',
              count: seriesCount,
              isSelected: selected == 'tv',
              onTap: () => onSelect('tv'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanonOption extends StatelessWidget {
  /// Extra width added to the space before the count.
  static const double _countGap = 4;

  /// The track's 4 dp inset sits inside the hit area, so each half is a 48 dp target.
  final EdgeInsets inset;
  final String name;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CanonOption({
    super.key,
    required this.inset,
    required this.name,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor = isSelected ? TellyColors.textPrimaryOf(context) : TellyColors.textTertiaryOf(context);
    // Same accent label colour as the segmented control: AA on Overlay in both themes.
    final countColor = isSelected ? TellySegmentedControl.selectedLabelColor(context) : TellyColors.textTertiaryOf(context);
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: inset,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? TellyColors.cardOf(context) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? TellyColors.borderGlassOf(context) : Colors.transparent),
            ),
            child: Text.rich(
              TextSpan(
                text: name,
                children: [
                  if (count != null) ...[
                    // A wider space (about 8 dp) between the name and its count (#47 device check).
                    const TextSpan(text: ' ', style: TextStyle(letterSpacing: _countGap)),
                    TextSpan(
                      text: '$count',
                      style: TextStyle(color: countColor, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TellyTypography.labelLarge(color: nameColor).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}
