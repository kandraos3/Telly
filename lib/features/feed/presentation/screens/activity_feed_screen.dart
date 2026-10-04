import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/widgets/feed_activity_card.dart';
import 'package:telly_app/features/feed/presentation/widgets/upset_activity_card.dart';

/// SCR-05: Home / Social Activity Feed Screen (FE-301).
///
/// Features segmented tab switching (Following, Squads, Global),
/// high-visibility spicy upset cards, 1-tap queue saving, and spoiler comments.
class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  void _openComments(ActivityLog activity) {
    HapticsService.lightImpact();
    context.push(Routes.activity(activity.id), extra: activity);
  }

  void _handleReactionToggle(ActivityLog activity, FeedReactionType reaction) {
    ref.read(socialRepositoryProvider).toggleReaction(
          activityId: activity.id,
          reaction: reaction,
        );
    ref.invalidate(feedActivitiesProvider);
  }

  void _handleQueueToggle(ActivityLog activity, bool inQueue) {
    ref.read(socialRepositoryProvider).toggleQueue(
          activityId: activity.id,
          titleId: activity.titleId,
          addToQueue: inQueue,
        );
  }

  @override
  Widget build(BuildContext context) {
    final currentFilter = ref.watch(feedFilterProvider);
    final feedAsync = ref.watch(feedActivitiesProvider);

    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TellyColors.phosphorLime.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TellyColors.phosphorLime.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Text('📺', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    'TELLY',
                    style: TellyTypography.labelLarge(
                      color: TellyColors.phosphorLime,
                    ).copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: TellyColors.textPrimary),
            onPressed: () {
              HapticsService.selectionClick();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented Filter Tabs: [ Following ] | [ Squads ] | [ Global ]
            _buildSegmentedFilterBar(currentFilter),

            // Activity Feed List with Pull-to-Refresh
            Expanded(
              child: RefreshIndicator(
                color: TellyColors.phosphorLime,
                backgroundColor: TellyColors.backgroundCard,
                onRefresh: () async {
                  ref.invalidate(feedActivitiesProvider);
                  await ref.read(feedActivitiesProvider.future);
                },
                child: feedAsync.when(
                  data: (activities) {
                    if (activities.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];

                        if (activity.isUpset) {
                          return UpsetActivityCard(
                            key: Key('upset_card_${activity.id}'),
                            activity: activity,
                            onCardTap: () => _openComments(activity),
                            onCommentTap: () => _openComments(activity),
                            onReactionToggle: (reaction) =>
                                _handleReactionToggle(activity, reaction),
                            onQueueToggle: (inQueue) => _handleQueueToggle(activity, inQueue),
                          );
                        }

                        return FeedActivityCard(
                          key: Key('feed_card_${activity.id}'),
                          activity: activity,
                          onCardTap: () => _openComments(activity),
                          onCommentTap: () => _openComments(activity),
                          onReactionToggle: (reaction) =>
                              _handleReactionToggle(activity, reaction),
                          onQueueToggle: (inQueue) => _handleQueueToggle(activity, inQueue),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: TellyColors.phosphorLime),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error loading feed: $e', style: TellyTypography.bodyMedium()),
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
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Row(
        children: FeedFilter.values.map((filter) {
          final isSelected = filter == currentFilter;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticsService.selectionClick();
                ref.read(feedFilterProvider.notifier).state = filter;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? TellyColors.backgroundCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? TellyColors.borderGlass : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  filter.displayName,
                  style: TellyTypography.caption(
                    color: isSelected ? TellyColors.phosphorLime : TellyColors.textTertiary,
                  ).copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
              const Icon(Icons.people_outline_rounded, size: 56, color: TellyColors.textTertiary),
              const SizedBox(height: 16),
              Text(
                'No Activity Yet',
                style: TellyTypography.headlineSmall(
                  color: TellyColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Follow friends or join a Squad to see what cinephiles are watching, ranking, and debating!',
                  style: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TellyColors.phosphorLime,
                  foregroundColor: Colors.black,
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
