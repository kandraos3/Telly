import 'package:flutter/material.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../data/tracking_repository.dart';

/// "Watching now: Maya, Jordan" under the quick actions (SCR-08 §T.7, features/11 §5.4). It never
/// shows an episode. Hidden when nobody is watching.
class WatchingNowRow extends StatelessWidget {
  const WatchingNowRow({super.key, required this.watchers, required this.onOpenProfile});

  final TrackingWatchers watchers;

  /// Opens `/u/:handle`.
  final ValueChanged<String> onOpenProfile;

  static String _name(TrackingWatcher w) => w.displayName?.isNotEmpty == true ? w.displayName! : (w.username ?? 'Someone');

  /// "Maya, Jordan" up to three names, then "and N others".
  static String summary(TrackingWatchers w) {
    final names = [for (final x in w.watchers.take(3)) _name(x)];
    final others = w.total - names.length;
    if (others <= 0) return names.join(', ');
    return '${names.join(', ')} and $others other${others == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    if (watchers.watchers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        button: true,
        label: 'Watching now: ${summary(watchers)}',
        excludeSemantics: true,
        child: InkWell(
          key: const Key('watching_now_row'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => TellyFrostedSheet.show<void>(
            context: context,
            builder: (ctx) => _WatchersList(watchers: watchers, onOpenProfile: (h) {
              Navigator.of(ctx).pop();
              onOpenProfile(h);
            }),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                TellyAvatarStack(
                  people: [for (final w in watchers.watchers) (_name(w), w.avatarUrl)],
                  total: watchers.total,
                  max: 3,
                  radius: 10,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Watching now: ${summary(watchers)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: TellyColors.textTertiaryOf(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WatchersList extends StatelessWidget {
  const _WatchersList({required this.watchers, required this.onOpenProfile});

  final TrackingWatchers watchers;
  final ValueChanged<String> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('watchers_sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Watching now',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final w in watchers.watchers)
          ListTile(
            key: Key('watcher_${w.username ?? w.userId}'),
            contentPadding: EdgeInsets.zero,
            leading: TellyAvatar(name: WatchingNowRow._name(w), imageUrl: w.avatarUrl, radius: 18),
            title: Text(WatchingNowRow._name(w)),
            subtitle: w.username == null ? null : Text('@${w.username}'),
            onTap: w.username == null ? null : () => onOpenProfile(w.username!),
          ),
        if (watchers.total > watchers.watchers.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'and ${watchers.total - watchers.watchers.length} more',
              style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
