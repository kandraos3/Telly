import 'package:flutter/material.dart';

import '../services/haptics_service.dart';
import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// The Filter button chip that opens a screen's Filter sheet (component library §5.4,
/// epic #47); first used by the Queue (SCR-13).
///
/// A 40 dp pill in a 48 dp target. Idle it sits on Surface with a glass border; with
/// [activeCount] > 0 it takes the primary accent (15% fill, accent border and label) and
/// shows the count in a lime badge. Sort order is never counted by callers.
class TellyFilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onPressed;

  const TellyFilterButton({super.key, required this.activeCount, required this.onPressed});

  /// The badge sits on a fixed lime fill, so its colours don't change with the theme.
  static const badgeFill = TellyColors.phosphorLime;
  static const badgeText = Color(0xFF08090C);

  @override
  Widget build(BuildContext context) {
    final active = activeCount > 0;
    final accent = TellyColors.primaryAccentOf(context);
    final labelColor = active ? accent : TellyColors.textSecondaryOf(context);
    return Semantics(
      button: true,
      label: active ? 'Filter, $activeCount active' : 'Filter',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticsService.selectionClick();
          onPressed();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.15) : TellyColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? accent : TellyColors.borderGlassOf(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded, size: 16, color: labelColor),
                  const SizedBox(width: 6),
                  Text('Filter', style: TellyTypography.labelMedium(color: labelColor).copyWith(fontWeight: FontWeight.w800)),
                  if (active) ...[
                    const SizedBox(width: 6),
                    Container(
                      key: const Key('filter_button_badge'),
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: badgeFill, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '$activeCount',
                        style: TellyTypography.labelSmall(color: badgeText)
                            .copyWith(fontSize: 10, fontWeight: FontWeight.w800, height: 1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
