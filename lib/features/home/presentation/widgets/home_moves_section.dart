import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../../tracking/domain/tracking_item.dart';
import '../../../tracking/presentation/providers/tracking_providers.dart';
import '../../../tracking/presentation/widgets/tracking_actions.dart';
import '../../domain/friends_line.dart';
import '../../domain/home_moves.dart';
import '../providers/home_providers.dart';

/// Text on a lime fill, in both themes.
const _onLime = Color(0xFF08090C);

/// *Your moves* (`SCR-21` §21.3): at most four one-tap suggestions. Hidden when there are none.
class HomeMovesSection extends ConsumerWidget {
  const HomeMovesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeStateProvider);
    if (state.movesLoading) return const _MovesSkeleton();
    if (state.moves.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('home_moves'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const TellySectionHeader(label: 'YOUR MOVES'),
        const SizedBox(height: 8),
        for (final move in state.moves) ...[
          HomeMoveCard(key: Key('home_move_${move.kind.name}_${move.titleId ?? move.challengeSlug ?? ''}'), move: move),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MovesSkeleton extends StatelessWidget {
  const _MovesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('home_moves_loading'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              height: 56,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: TellyColors.cardOf(context), borderRadius: BorderRadius.circular(14)),
            ),
        ],
      ),
    );
  }
}

/// One move: an icon tile, a kicker, a title, a meta line and one trailing button. Tapping the card does what the
/// button does.
class HomeMoveCard extends ConsumerWidget {
  const HomeMoveCard({super.key, required this.move});

  final HomeMove move;

  static IconData _icon(HomeMoveKind kind) => switch (kind) {
        HomeMoveKind.rankFinished => Icons.star_rounded,
        HomeMoveKind.newEpisodes => Icons.fiber_new_rounded,
        HomeMoveKind.streakAtRisk => Icons.local_fire_department_rounded,
        HomeMoveKind.challenge => Icons.flag_rounded,
        HomeMoveKind.friendCompare => Icons.compare_arrows_rounded,
        HomeMoveKind.queuePick => Icons.play_arrow_rounded,
        HomeMoveKind.startTracking => Icons.add_task_rounded,
        HomeMoveKind.findFriends => Icons.person_add_alt_1_rounded,
      };

  static Color _accent(BuildContext context, HomeMoveAccent accent) => switch (accent) {
        HomeMoveAccent.lime => TellyColors.primaryAccentOf(context),
        HomeMoveAccent.amber => TellyColors.warmAmberOf(context),
        HomeMoveAccent.coral => TellyColors.neonCoralOf(context),
        HomeMoveAccent.violet => TellyColors.electricVioletOf(context),
      };

  /// Runs the move's button, then re-derives the moves (§21.6).
  Future<void> _act(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(homeStateProvider.notifier);
    Future<void> push(String location, {Object? extra}) async {
      await context.push<Object?>(location, extra: extra);
      if (context.mounted) notifier.refresh();
    }

    final id = move.titleId;
    final type = move.mediaType;
    switch (move.kind) {
      case HomeMoveKind.rankFinished:
        final items = ref.read(trackingProvider).valueOrNull ?? const <TrackingItem>[];
        final item = items.where((i) => i.titleId == id && i.mediaType == type).firstOrNull;
        if (item == null) return push(Routes.title(type!, id!));
        TrackingActions.rank(context, item);
        return;
      case HomeMoveKind.newEpisodes || HomeMoveKind.friendCompare || HomeMoveKind.queuePick:
        return push(Routes.title(type!, id!));
      case HomeMoveKind.streakAtRisk:
        return push(Routes.log);
      case HomeMoveKind.challenge:
        return push(Routes.challenge(move.challengeSlug!));
      case HomeMoveKind.startTracking:
        context.go(Routes.exploreSearch());
        return;
      case HomeMoveKind.findFriends:
        return push(Routes.userSearch);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _accent(context, move.accent);
    final primary = move.kind == HomeMoveKind.rankFinished || move.kind == HomeMoveKind.streakAtRisk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        container: true,
        button: true,
        label: '${move.kicker}. ${move.title}. ${move.meta}. ${move.buttonLabel}',
        child: Material(
          color: TellyColors.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: TellyColors.strokeOf(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _act(context, ref),
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
                        child: Icon(_icon(move.kind), size: 18, color: accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              move.kicker,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.caption(color: accent)
                                  .copyWith(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1),
                            ),
                            Text(
                              move.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              move.meta,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MoveButton(label: move.buttonLabel, primary: primary, onPressed: () => _act(context, ref)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({required this.label, required this.primary, required this.onPressed});

  final String label;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Center(
        child: SizedBox(
          height: 32,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: primary ? TellyColors.phosphorLime : TellyColors.cardOf(context),
              foregroundColor: primary ? _onLime : TellyColors.textPrimaryOf(context),
              side: BorderSide(color: primary ? TellyColors.phosphorLime : TellyColors.strokeOf(context)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: TellyTypography.labelMedium(color: primary ? _onLime : TellyColors.textPrimaryOf(context))
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Friends line (`SCR-21` §21.4): overlapping avatars, who, and what. Opens Social. Hidden when there's nothing.
class HomeFriendsLine extends ConsumerWidget {
  const HomeFriendsLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FriendsLineData? line = ref.watch(homeStateProvider.select((s) => s.friends));
    if (line == null) return const SizedBox.shrink(key: Key('home_friends_hidden'));
    return Column(
      key: const Key('home_friends_line'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        TellySectionHeader(
          label: 'FRIENDS',
          trailing: TextButton(
            key: const Key('home_friends_see_all'),
            onPressed: () => context.go(Routes.social),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(
              'Social ›',
              style: TellyTypography.labelLarge(color: TellyColors.primaryAccentOf(context))
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            container: true,
            button: true,
            label: '${line.title}, ${line.meta}',
            child: Material(
              color: TellyColors.surfaceOf(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: TellyColors.strokeOf(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('home_friends_card'),
                onTap: () => context.go(Routes.social),
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          TellyAvatarStack(
                            people: [for (final f in line.faces) (f.name, f.avatarUrl)],
                            max: FriendsLine.maxFaces,
                            radius: 12,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.title,
                                  key: const Key('home_friends_title'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  line.meta,
                                  key: const Key('home_friends_meta'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: TellyColors.textTertiaryOf(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The lime "▲ N weeks" chip in Home's header (`SCR-21` §21.1). Opens Your level. Hidden at 0 weeks.
class HomeStreakChip extends ConsumerWidget {
  const HomeStreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = ref.watch(homeStateProvider.select((s) => s.streakWeeks));
    if (weeks < 1) return const SizedBox.shrink();
    final accent = TellyColors.primaryAccentOf(context);
    final label = '▲ $weeks ${weeks == 1 ? 'week' : 'weeks'}';
    return Semantics(
      button: true,
      label: 'Weekly streak, $weeks ${weeks == 1 ? 'week' : 'weeks'}',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('home_streak_chip'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.push(Routes.level),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child:
                  Text(label, style: TellyTypography.labelMedium(color: accent).copyWith(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }
}
