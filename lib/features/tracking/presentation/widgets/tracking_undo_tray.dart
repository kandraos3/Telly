import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_log_fab.dart';

/// The 6 s "S2 · E6 watched · Undo" toast (features/11 §4.2). It is a tray rather than a plain
/// snackbar so #216 can add a reaction row in [trailing] without changing the flow.
abstract final class TrackingUndoTray {
  static const duration = Duration(seconds: 6);

  static void show(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Widget? trailing,

    /// On a tab that shows the floating Log button (Home), the toast floats above it so Undo stays tappable.
    bool aboveLogButton = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        key: const Key('tracking_undo_tray'),
        duration: duration,
        backgroundColor: TellyColors.cardOf(context),
        behavior: SnackBarBehavior.floating,
        margin: aboveLogButton ? const EdgeInsets.fromLTRB(16, 0, 16, 8 + TellyLogFab.clearance) : null,
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
