import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/discovery/domain/discovery_models.dart';
import 'package:telly_app/features/feed/presentation/controllers/feed_controllers.dart';
import 'package:telly_app/features/feed/presentation/controllers/feed_recommendations.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';
import 'package:telly_app/features/feed/presentation/widgets/feed_recommendation_card.dart';
import 'package:telly_app/features/feed/presentation/widgets/moderation_sheet.dart';
import 'package:telly_app/features/feed/presentation/widgets/feed_activity_card.dart';
import 'package:telly_app/features/feed/presentation/widgets/upset_activity_card.dart';

/// SCR-05: Home / Social Activity Feed Screen (FE-301).
///
/// Features segmented tab switching (Following, Squads, Global),
/// high-visibility spicy upset cards, 1-tap queue saving, and spoiler comments.
/// FE-607: served by `get_activity_feed` through [FeedController] (keyset pagination,
/// optimistic reactions/queue with rollback); long-press opens report/block.
class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  /// Start fetching the next page this far from the bottom.
  static const _prefetchExtent = 400.0;

  FeedController get _feed => ref.read(feedControllerProvider(ref.read(feedFilterProvider)).notifier);

  /// The list scrolls on the header's primary controller (FE-HEADER-01), so paging
  /// listens to its scroll notifications instead of owning a controller.
  bool _maybeLoadMore(ScrollUpdateNotification n) {
    if (n.depth == 0 && n.metrics.extentAfter < _prefetchExtent) _feed.loadMore();
    return false;
  }

  void _openComments(ActivityLog activity) {
    HapticsService.lightImpact();
    context.push(Routes.activity(activity.id), extra: activity);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save that. Check your connection.")),
        );
      }
    }
  }

  void _handleReactionToggle(ActivityLog activity, FeedReaction reaction) =>
      _guard(() => _feed.toggleReaction(activity.id, reaction));

  void _handleQueueToggle(ActivityLog activity, bool inQueue) => _guard(() => _feed.setQueued(activity.id, inQueue));

  Widget _buildRecommendation(RecommendedTitle pick, FeedRecommendations recs) {
    return FeedRecommendationCard(
      key: Key('feed_rec_${pick.mediaType}_${pick.titleId}'),
      title: pick,
      queued: recs.isQueued(pick),
      onOpen: () => context.push(Routes.title(pick.mediaType, pick.titleId)),
      onQueue: () {
        HapticsService.lightImpact();
        _guard(() => ref.read(feedRecommendationsProvider.notifier).queue(pick));
      },
      onRank: () => context.push(
        Routes.log,
        extra: TitleSearchResult(
          id: pick.titleId,
          mediaType: pick.mediaType,
          title: pick.title,
          posterPath: pick.posterPath,
          releaseYear: pick.releaseYear?.toString() ?? '',
        ),
      ),
    );
  }

  void _openModeration(ActivityLog activity) {
    showModerationSheet(
      context: context,
      ref: ref,
      target: ReportTarget.activity,
      targetId: activity.id,
      authorId: activity.userId,
      authorHandle: activity.username,
      onReported: () => _forEachFeed((f) => f.hideActivity(activity.id)),
      onBlocked: () => _forEachFeed((f) => f.hideUser(activity.userId)),
    );
  }

  void _forEachFeed(void Function(FeedController) action) {
    for (final filter in FeedFilter.values) {
      if (ref.exists(feedControllerProvider(filter))) action(ref.read(feedControllerProvider(filter).notifier));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFilter = ref.watch(feedFilterProvider);
    final feedAsync = ref.watch(feedControllerProvider(currentFilter));

    return Scaffold(
      body: TellyFloatingHeaderScrollView(
        header: TellyScreenHeader(
          title: 'Feed',
          actions: [
            // FE-SQUADS-01: Squads one tap from the home tab, not only behind the profile icon.
            TellyHeaderAction(
              key: const Key('feed_squads_button'),
              icon: Icons.groups_2_outlined,
              tooltip: 'My Squads',
              onPressed: () => context.push(Routes.squads),
            ),
            TellyHeaderAction(
              key: const Key('feed_search_button'),
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onPressed: () => context.go(Routes.exploreSearch()),
            ),
          ],
        ),
        body: Column(
          children: [
            // Segmented Filter Tabs: [ Following ] | [ Squads ] | [ Global ]
            _buildSegmentedFilterBar(currentFilter),

            // Activity Feed List with Pull-to-Refresh
            Expanded(
              child: RefreshIndicator(
                color: TellyColors.primaryAccentOf(context),
                backgroundColor: TellyColors.cardOf(context),
                onRefresh: () => _feed.refresh(),
                child: feedAsync.when(
                  data: (feed) {
                    final activities = feed.items;
                    if (activities.isEmpty) {
                      return _buildEmptyState();
                    }
                    // FE-FEED-02: a "Picked for you" card after every few posts.
                    final recs = ref.watch(feedRecommendationsProvider).valueOrNull ?? const FeedRecommendations();
                    final entries = interleaveRecommendations(activities, recs.picks);

                    return NotificationListener<ScrollUpdateNotification>(
                      onNotification: _maybeLoadMore,
                      child: ListView.builder(
                        key: const Key('feed_list'),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(top: 8, bottom: 120),
                        itemCount: entries.length + (feed.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == entries.length) {
                            return Padding(
                              key: const Key('feed_page_loader'),
                              padding: const EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
                            );
                          }
                          final entry = entries[index];
                          final ActivityLog activity;
                          switch (entry) {
                            case RecommendationEntry(:final title):
                              return _buildRecommendation(title, recs);
                            case ActivityEntry(activity: final a):
                              activity = a;
                          }

                          final Widget card;
                          if (activity.isUpset) {
                            card = UpsetActivityCard(
                              key: Key('upset_card_${activity.id}'),
                              activity: activity,
                              onCardTap: () => _openComments(activity),
                              onCommentTap: () => _openComments(activity),
                              onReactionToggle: (reaction) => _handleReactionToggle(activity, reaction),
                              onQueueToggle: (inQueue) => _handleQueueToggle(activity, inQueue),
                            );
                          } else {
                            card = FeedActivityCard(
                              key: Key('feed_card_${activity.id}'),
                              activity: activity,
                              onCardTap: () => _openComments(activity),
                              onCommentTap: () => _openComments(activity),
                              onReactionToggle: (reaction) => _handleReactionToggle(activity, reaction),
                              onQueueToggle: (inQueue) => _handleQueueToggle(activity, inQueue),
                            );
                          }
                          // SCR-05: long-press opens the context menu (report / block).
                          return GestureDetector(onLongPress: () => _openModeration(activity), child: card);
                        },
                      ),
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context)),
                  ),
                  error: (e, _) => ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          "Couldn't load the feed. Pull to retry.",
                          key: const Key('feed_error_text'),
                          style: TellyTypography.bodyMedium(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedFilterBar(FeedFilter currentFilter) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Row(
        children: FeedFilter.values.map((filter) {
          final isSelected = filter == currentFilter;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticsService.selectionClick();
                ref.read(feedFilterProvider.notifier).select(filter);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? TellyColors.cardOf(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? TellyColors.borderGlassOf(context) : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  filter.displayName,
                  style: TellyTypography.labelMedium(
                    color: isSelected
                        ? (Theme.of(context).brightness == Brightness.light
                            ? const Color(0xFF233B00)
                            : TellyColors.phosphorLime)
                        : TellyColors.textPrimaryOf(context),
                  ).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 56, color: TellyColors.textTertiaryOf(context)),
              const SizedBox(height: 16),
              Text(
                'No Activity Yet',
                style: TellyTypography.headlineSmall(
                  color: TellyColors.textPrimaryOf(context),
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Follow friends or join a Squad to see what cinephiles are watching, ranking, and debating!',
                  style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)).copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TellyColors.primaryAccentOf(context),
                  foregroundColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  HapticsService.mediumImpact();
                },
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Find Friends', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
