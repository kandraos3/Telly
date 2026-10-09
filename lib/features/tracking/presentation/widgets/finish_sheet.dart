import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../logging/domain/watch_status.dart';
import '../../domain/tracking_item.dart';
import '../../domain/tracking_models.dart';

enum FinishAction { logAndDuel, later, reDuel, keepRank }

class FinishResult {
  const FinishResult(this.action, {this.status});

  final FinishAction action;

  /// The watch status picked for [FinishAction.logAndDuel].
  final WatchStatus? status;
}

/// features/11 §4.5 / SCR-08 §T.8. Opens only when a write finishes or catches up a title, and
/// acts only on a tap.
class FinishSheet extends StatefulWidget {
  const FinishSheet({super.key, required this.item});

  final TrackingItem item;

  static Future<FinishResult?> show(BuildContext context, TrackingItem item) {
    return TellyFrostedSheet.show<FinishResult>(context: context, builder: (_) => FinishSheet(item: item));
  }

  /// The status to preselect (features/11 §4.5).
  static WatchStatus defaultStatus(TrackingItem item) {
    if (item.isMovie) return item.isRewatch ? WatchStatus.rewatch : WatchStatus.firstTime;
    return item.state == TrackingState.caughtUp ? WatchStatus.upToDate : WatchStatus.finished;
  }

  @override
  State<FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<FinishSheet> {
  late WatchStatus _status = FinishSheet.defaultStatus(widget.item);

  List<WatchStatus> get _options => widget.item.isMovie
      ? const [WatchStatus.firstTime, WatchStatus.rewatch]
      : const [WatchStatus.finished, WatchStatus.upToDate];

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final headline = item.state == TrackingState.caughtUp ? "You're up to date on ${item.title}" : 'You finished ${item.title}';
    final lime = TellyColors.primaryAccentOf(context);
    return Column(
      key: const Key('finish_sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (item.isRanked) ...[
          Text(
            'Your rank: #${item.rankPosition}${item.score == null ? '' : ' · ${item.score!.toStringAsFixed(2)}'}',
            key: const Key('finish_rank_line'),
            style: TellyTypography.bodyMedium(color: TellyColors.warmAmberOf(context)).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TellyPrimaryButton(
            key: const Key('finish_reduel_button'),
            label: 'Re-duel →',
            onPressed: () => Navigator.of(context).pop(const FinishResult(FinishAction.reDuel)),
          ),
          TextButton(
            key: const Key('finish_keep_button'),
            onPressed: () => Navigator.of(context).pop(const FinishResult(FinishAction.keepRank)),
            child: const Text('Keep my rank'),
          ),
        ] else ...[
          for (final s in _options)
            InkWell(
              key: Key('finish_status_${s.name}'),
              onTap: () => setState(() => _status = s),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(_status == s ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _status == s ? lime : TellyColors.textTertiaryOf(context), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.label, style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          TellyPrimaryButton(
            key: const Key('finish_log_button'),
            label: 'Log and duel →',
            onPressed: () => Navigator.of(context).pop(FinishResult(FinishAction.logAndDuel, status: _status)),
          ),
          TextButton(
            key: const Key('finish_later_button'),
            onPressed: () => Navigator.of(context).pop(const FinishResult(FinishAction.later)),
            child: const Text('Later'),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
