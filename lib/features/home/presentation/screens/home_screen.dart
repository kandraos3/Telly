import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_canon_switcher.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_log_fab.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../feed/data/social_repository.dart';
import '../../../feed/domain/social_models.dart';
import '../../../feed/presentation/controllers/feed_controllers.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/widgets/poster_grid_view.dart';
import '../../../ranking/domain/canon_type.dart';
import '../../../ranking/presentation/widgets/canon_tier_style.dart';

/// `SCR-21` Home (epic #44): the landing tab. Interim content built only from data the app already has —
/// the top of the selected canon and the newest Following activity — until epic #45 designs the real Home.
/// Spec: `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` `SCR-21`.
class HomeScreen extends ConsumerWidget {
  /// How many canon titles and friend rows the sections show.
  static const previewCount = 3;

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: TellyFloatingHeaderScrollView(
        header: TellyScreenHeader(
          title: 'Home',
          actions: [
            TellyHeaderAction(
              key: const Key('home_search_button'),
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onPressed: () => context.go(Routes.exploreSearch()),
            ),
          ],
        ),
        // The header's safe area clears the nav bar; the end space lets the last row scroll above the Log button.
        body: const SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.only(top: 8, bottom: 24 + TellyLogFab.clearance),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CanonSection(),
              SizedBox(height: 24),
              _FriendsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _seeAll(BuildContext context, {required Key key, required VoidCallback onTap}) => TextButton(
      key: key,
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      child: Text(
        'See all',
        style: TellyTypography.labelLarge(color: TellyColors.primaryAccentOf(context))
            .copyWith(fontWeight: FontWeight.bold),
      ),
    );

/// Top [HomeScreen.previewCount] of the selected canon. Movies and series are never mixed.
class _CanonSection extends ConsumerWidget {
  const _CanonSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canon = ref.watch(selectedCanonProvider);
    final rollupAnime = ref.watch(franchiseRollupProvider);
    final state = ref.watch(profileCanonProvider);
    final top = state.entriesFor(canon, rollupAnime: rollupAnime).take(HomeScreen.previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TellySectionHeader(
          label: 'YOUR CANON',
          trailing: _seeAll(context, key: const Key('home_canon_see_all'), onTap: () => context.go(Routes.canon)),
        ),
        const SizedBox(height: 8),
        TellyCanonSwitcher(
          selected: canon.dbValue,
          movieKey: const Key('home_canon_movies'),
          seriesKey: const Key('home_canon_series'),
          onSelect: (value) => ref
              .read(selectedCanonProvider.notifier)
              .select(value == CanonType.movie.dbValue ? CanonType.movie : CanonType.series),
        ),
        const SizedBox(height: 8),
        if (state.isLoading && top.isEmpty)
          const _PosterSkeletonRow()
        else if (top.isEmpty)
          TellyEmptyState(
            key: const Key('home_canon_empty'),
            icon: Icons.emoji_events_outlined,
            title: 'Log your first title to start your canon',
            message: 'Rank what you watch and your ${canon.shortLabel.toLowerCase()} canon builds itself.',
            actionLabel: 'Log',
            actionIcon: Icons.add_rounded,
            actionKey: const Key('home_canon_empty_log'),
            onAction: () => context.push(Routes.log),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          )
        else
          PosterGridView(
            key: const Key('home_canon_posters'),
            entries: top,
            onTapEntry: (entry) => context.push(Routes.title(entry.mediaType, entry.id)),
          ),
      ],
    );
  }
}

class _PosterSkeletonRow extends StatelessWidget {
  const _PosterSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('home_canon_loading'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < HomeScreen.previewCount; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: TellyColors.cardOf(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The newest [HomeScreen.previewCount] items of the Following feed by other people, sharing the Social tab's
/// controller.
class _FriendsSection extends ConsumerWidget {
  const _FriendsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider(FeedFilter.following));
    // The Following feed includes my own posts; this section shows only other people (#121).
    final me = ref.watch(authControllerProvider.select((s) => s.user?.id));
    final items = feed.valueOrNull?.items.where((a) => a.userId != me).toList();

    // Offline or failing with nothing loaded yet: the section hides rather than showing an error.
    if (items == null && feed.hasError) return const SizedBox.shrink(key: Key('home_friends_hidden'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TellySectionHeader(
          label: 'FROM YOUR FRIENDS',
          trailing: _seeAll(context, key: const Key('home_friends_see_all'), onTap: () => context.go(Routes.social)),
        ),
        const SizedBox(height: 8),
        if (items == null)
          const _RowSkeletons()
        else if (items.isEmpty)
          TellyEmptyState(
            key: const Key('home_friends_empty'),
            icon: Icons.people_outline_rounded,
            title: 'Find friends in Social',
            message: 'Follow friends to see what they rank.',
            actionLabel: 'Open Social',
            actionKey: const Key('home_friends_empty_action'),
            onAction: () => context.go(Routes.social),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          )
        else
          for (final activity in items.take(HomeScreen.previewCount)) _FriendRow(activity: activity),
      ],
    );
  }
}

class _RowSkeletons extends StatelessWidget {
  const _RowSkeletons();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home_friends_loading'),
      children: [
        for (var i = 0; i < HomeScreen.previewCount; i++)
          Container(
            height: 60,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(color: TellyColors.cardOf(context), borderRadius: BorderRadius.circular(16)),
          ),
      ],
    );
  }
}

/// Compact friend activity row: avatar, "<name> <verb> <title> #N", tier-coloured score chip.
class _FriendRow extends StatelessWidget {
  final ActivityLog activity;
  const _FriendRow({required this.activity});

  /// Sentence after the friend's name, e.g. `ranked Severance #2`.
  static String describe(ActivityLog a) {
    final rank = a.rankPosition == null ? '' : ' #${a.rankPosition}';
    return switch (a.activityType) {
      ActivityType.rankingCreated || ActivityType.upsetAlert => 'ranked ${a.titleName}$rank',
      ActivityType.showDropped => 'dropped ${a.titleName}',
      ActivityType.queueAdded => 'queued ${a.titleName}',
      ActivityType.commentPosted => 'commented on ${a.titleName}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final score = activity.calculatedScore;
    final showScore = score != null && activity.activityType != ActivityType.showDropped;
    final name = activity.userDisplayName.isEmpty ? '@${activity.username}' : activity.userDisplayName;
    final sentence = describe(activity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Semantics(
        container: true,
        button: true,
        label: '$name $sentence${showScore ? ', score ${score.toStringAsFixed(2)}' : ''}',
        child: Material(
          key: Key('home_friend_row_${activity.id}'),
          color: TellyColors.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: TellyColors.strokeOf(context)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(Routes.title(activity.mediaType, activity.titleId)),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    TellyAvatar(name: name, imageUrl: activity.userAvatarUrl, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: name,
                            style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' $sentence'),
                        ]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
                      ),
                    ),
                    if (showScore) ...[
                      const SizedBox(width: 10),
                      CanonTierScoreChip(key: const Key('home_score_chip'), score: score),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
