import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// Upper-case section label with a hairline rule, as on the Canon's "TOP 3 SHOWCASE"
/// (FE-UI-01). An optional [trailing] widget (a count, a hint) sits after the rule.
///
/// The label is a single [Text] so it stays findable and reads cleanly to screen readers.
class TellySectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const TellySectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final muted = TellyColors.textTertiaryOf(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(width: 10, height: 2, color: muted),
          const SizedBox(width: 6),
          Semantics(
            header: true,
            child: Text(
              label,
              style: TellyTypography.caption(color: muted).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: TellyColors.borderGlassOf(context))),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
