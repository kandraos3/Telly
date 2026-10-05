import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../theme/telly_typography.dart';

/// Honest placeholder for a routed screen whose ticket has not landed yet.
/// Every use names its ticket; `QA-608` fails if any remain at the end of Sprint 6.
class PendingScreen extends StatelessWidget {
  final String title;
  final String ticket;
  final Widget? action;

  const PendingScreen({super.key, required this.title, required this.ticket, this.action});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      appBar: AppBar(
        backgroundColor: TellyColors.canvasOf(context),
        title: Text(title, style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined, color: TellyColors.textTertiaryOf(context), size: 40),
              const SizedBox(height: 12),
              Text('$title is not built yet', style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
              const SizedBox(height: 4),
              Text('Tracked by $ticket', style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}
