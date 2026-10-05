import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// The Movies / TV Shows selector shared by Canon (SCR-14), Queue (SCR-13) and the
/// Squad hub (SCR-17b) (FE-UI-01). Movies always sits on the left.
///
/// A Surface track whose selected half fills with the primary accent and glows. Labels
/// carry a count when one is given ("Movies (12)"). Callers own haptics and state; the
/// switcher only reports `'movie'` or `'tv'`.
class TellyCanonSwitcher extends StatelessWidget {
  /// `'movie'` or `'tv'`.
  final String selected;
  final ValueChanged<String> onSelect;
  final int? movieCount;
  final int? seriesCount;

  /// Optional quiet second line under TV Shows (Canon: "Includes anime").
  final String? seriesSubtitle;
  final Key? movieKey;
  final Key? seriesKey;
  final EdgeInsetsGeometry margin;

  const TellyCanonSwitcher({
    super.key,
    required this.selected,
    required this.onSelect,
    this.movieCount,
    this.seriesCount,
    this.seriesSubtitle,
    this.movieKey,
    this.seriesKey,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  static String _label(String name, int? count) => count == null ? name : '$name ($count)';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CanonOption(
              key: movieKey,
              label: _label('Movies', movieCount),
              isSelected: selected == 'movie',
              onTap: () => onSelect('movie'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _CanonOption(
              key: seriesKey,
              label: _label('TV Shows', seriesCount),
              subtitle: seriesSubtitle,
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
  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _CanonOption({super.key, required this.label, this.subtitle, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final onAccent = isLight ? Colors.white : const Color(0xFF08090C);
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? TellyColors.primaryAccentOf(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: TellyColors.primaryAccentOf(context).withValues(alpha: 0.25), blurRadius: 10)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TellyTypography.labelSmall(color: isSelected ? onAccent : TellyColors.textPrimaryOf(context))
                    .copyWith(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700, fontSize: 12),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? (isLight ? Colors.white70 : const Color(0xFF08090C).withValues(alpha: 0.7))
                        : TellyColors.textSecondaryOf(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
