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
      backgroundColor: TellyColors.backgroundPrimary,
      appBar: AppBar(title: Text(title, style: TellyTypography.titleMedium())),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, color: TellyColors.textTertiary, size: 40),
              const SizedBox(height: 12),
              Text('$title is not built yet', style: TellyTypography.titleMedium()),
              const SizedBox(height: 4),
              Text('Tracked by $ticket', style: TellyTypography.caption(color: TellyColors.textTertiary)),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}
