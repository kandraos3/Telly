import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';

/// The 6 s "S2 · E6 watched · Undo" toast (features/11 §4.2). It is a tray rather than a plain
/// snackbar so #216 can add a reaction row in [trailing] without changing the flow.
abstract final class TrackingUndoTray {
  static const duration = Duration(seconds: 6);

  static void show(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Widget? trailing,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        key: const Key('tracking_undo_tray'),
        duration: duration,
        backgroundColor: TellyColors.cardOf(context),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Expanded(
              child: Text(message, style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))),
            ),
            if (trailing != null) trailing,
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: TellyColors.primaryAccentOf(context),
          onPressed: onUndo,
        ),
      ),
    );
  }
}
