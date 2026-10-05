import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';
import 'telly_primary_button.dart';

/// Empty state with an optional call to action
/// (`docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md` §7.2, FE-UI-01).
///
/// A muted icon, a short title, one line of guidance and, when [actionLabel] is set, a
/// Phosphor Lime button that leads somewhere useful. Not scrollable itself; callers that
/// need pull-to-refresh wrap it in a scroll view.
class TellyEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Key? actionKey;
  final EdgeInsetsGeometry padding;

  const TellyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionKey,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TellyColors.surfaceOf(context),
              border: Border.all(color: TellyColors.borderGlassOf(context)),
            ),
            child: Icon(icon, size: 32, color: TellyColors.textTertiaryOf(context)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            // w600: thin 13 px text antialiases below AA contrast on the light canvas.
            style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)).copyWith(fontWeight: FontWeight.w600),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: TellyPrimaryButton(
                key: actionKey,
                label: actionLabel!,
                height: 48,
                icon: actionIcon == null ? null : Icon(actionIcon, size: 18, color: const Color(0xFF08090C)),
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
