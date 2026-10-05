import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

/// Report / block actions for user-generated content (FE-607; features/04, App Store 1.2).
///
/// Calls `submit_report` / `block_user`; [onReported] / [onBlocked] run only on success so
/// the caller can hide the content immediately for the current user.
Future<void> showModerationSheet({
  required BuildContext context,
  required WidgetRef ref,
  required ReportTarget target,
  required String targetId,
  required String authorId,
  required String authorHandle,
  required VoidCallback onReported,
  required VoidCallback onBlocked,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: TellyColors.cardOf(context),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Report', style: TellyTypography.labelLarge(color: TellyColors.textSecondaryOf(context))),
          ),
          for (final reason in ReportReason.values)
            ListTile(
              key: Key('report_reason_${reason.name}'),
              leading: const Icon(Icons.flag_outlined, color: TellyColors.neonCoral),
              title: Text(reason.label, style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))),
              onTap: () => Navigator.of(ctx).pop(reason),
            ),
          Divider(color: TellyColors.strokeSubtleOf(context), height: 1),
          ListTile(
            key: const Key('block_user_action'),
            leading: const Icon(Icons.block, color: TellyColors.neonCoral),
            title: Text('Block @$authorHandle', style: TellyTypography.bodyLarge(color: TellyColors.neonCoral)),
            onTap: () => Navigator.of(ctx).pop(#block),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return;

  final repo = ref.read(socialRepositoryProvider);
  try {
    if (choice is ReportReason) {
      await repo.report(target: target, targetId: targetId, reason: choice);
      onReported();
      messenger.showSnackBar(const SnackBar(content: Text('Thanks. Our moderators will review it.')));
    } else {
      await repo.blockUser(authorId);
      onBlocked();
      messenger.showSnackBar(SnackBar(content: Text('@$authorHandle is blocked.')));
    }
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text("That didn't go through. Please try again.")));
  }
}
