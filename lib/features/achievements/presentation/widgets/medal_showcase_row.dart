import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../domain/medal.dart';
import 'medal_badge.dart';

/// Small medals under a name: the More profile card (`SCR-22`) and the friend profile
/// (`SCR-15`), features/10 §4.4. Pinned medals in slot order, or the latest unlocks with a
/// quiet "Recent" label. Renders nothing for an empty showcase.
class MedalShowcaseRow extends StatelessWidget {
  final MedalShowcase showcase;

  const MedalShowcaseRow({super.key, required this.showcase});

  @override
  Widget build(BuildContext context) {
    if (showcase.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: showcase.semanticLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in showcase.medals) ...[
            MedalBadge.of(m, size: MedalSize.small),
            const SizedBox(width: 6),
          ],
          if (showcase.isRecent) ...[
            const SizedBox(width: 2),
            Text('Recent', style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
          ],
        ],
      ),
    );
  }
}
