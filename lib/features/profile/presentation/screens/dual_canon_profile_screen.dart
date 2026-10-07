import 'package:flutter/material.dart';
import 'package:telly_app/core/widgets/telly_log_fab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_canon_switcher.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../logging/domain/title_search_result.dart';
import '../../../ranking/domain/canon_type.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';
import '../../data/profile_share_service.dart';
import '../controllers/edit_profile_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/canon_stats_panel.dart';
import '../widgets/poster_grid_view.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/ranked_canon_list.dart';
import '../widgets/tier_view_list.dart';
import '../widgets/top_showcase_row.dart';

/// SCR-14 Dual-Canon Profile Screen with Segmented Canon Pill Switcher,
/// Three View Modes (Ranked, Tiers, 3x3 Grid), Franchise Rollup, and Drag-and-Drop.
/// Conforms to:
/// - `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §14 (SCR-14)
/// - `docs/features/06_PROFILE_THE_CANON_AND_STATS.md` §1–§3
/// - `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §2
/// - `docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md` §2
/// - Tickets: FE-206, FE-207, FE-208, FE-209
class DualCanonProfileScreen extends ConsumerWidget {
  final VoidCallback? onShareTap;
  final VoidCallback? onAvatarTap;
  final ValueChanged<CanonEntry>? onTapEntry;

  const DualCanonProfileScreen({
    super.key,
    this.onShareTap,
    this.onAvatarTap,
    this.onTapEntry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCanon = ref.watch(selectedCanonProvider);
    final viewMode = ref.watch(canonViewModeProvider);
    final rollupAnime = ref.watch(franchiseRollupProvider);
    final canonState = ref.watch(profileCanonProvider);
    final me = ref.watch(authControllerProvider.select((s) => s.user));

    final entries = canonState.entriesFor(
      selectedCanon,
      rollupAnime: rollupAnime,
    );

    final moviesCount = canonState.movies.length;
    final seriesCount = canonState.series.length;

    final handleTap = onTapEntry ??
        (CanonEntry entry) {
          context.push(Routes.title(entry.mediaType, entry.id));
        };

    final onShare = onShareTap ??
        () => ref.read(profileShareServiceProvider).shareProfile(
              handle: me?.username ?? '',
              displayName: me?.displayName ?? '',
              topMovies: [for (final e in canonState.movies) e.title],
              topSeries: [for (final e in canonState.series) e.title],
            );

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -200 && selectedCanon == CanonType.movie) {
            ref.read(hapticsServiceProvider).duelSelectCandidate();
            ref.read(selectedCanonProvider.notifier).select(CanonType.series);
          } else if (velocity > 200 && selectedCanon == CanonType.series) {
            ref.read(hapticsServiceProvider).duelSelectCandidate();
            ref.read(selectedCanonProvider.notifier).select(CanonType.movie);
          }
        },
        child: TellyFloatingHeaderScrollView(
          // FE-HEADER-01: the shared tab header. Settings moved to More and Squads to Social (#44).
          header: TellyScreenHeader(
            title: 'Canon',
            actions: [
              TellyHeaderAction(
                key: const Key('profile_share_button'),
                icon: Icons.ios_share_rounded,
                tooltip: 'Share profile',
                onPressed: onShare,
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PROFILE HEADER CARD (Avatar, Handle, Bio, Stats)
                ProfileHeaderCard(
                  displayName: me?.displayName ?? '',
                  handle: me?.username == null ? '' : '@${me!.username}',
                  bio: me?.bio,
                  avatarUrl: me?.avatarUrl,
                  movieCount: moviesCount,
                  seriesCount: seriesCount,
                  onAvatarTap: onAvatarTap ?? () => context.push(Routes.editProfile),
                ),

                const SizedBox(height: 16),

                // 2. SEGMENTED DUAL-CANON SELECTOR (FE-206), the shared switcher (FE-UI-01)
                TellyCanonSwitcher(
                  selected: selectedCanon == CanonType.movie ? 'movie' : 'tv',
                  movieCount: moviesCount,
                  seriesCount: seriesCount,
                  seriesSubtitle: 'Includes anime',
                  movieKey: const Key('movie_canon_tab'),
                  seriesKey: const Key('series_canon_tab'),
                  onSelect: (mediaType) {
                    ref.read(hapticsServiceProvider).duelSelectCandidate();
                    ref.read(selectedCanonProvider.notifier).select(mediaType == 'movie' ? CanonType.movie : CanonType.series);
                  },
                ),

              const SizedBox(height: 12),

              // 2b. PER-CANON STATS DASHBOARD (FE-PROFILE-03) — follows the selected tab.
              CanonStatsPanel(
                stats: ref.watch(canonStatsProvider(selectedCanon)).valueOrNull,
                isMovie: selectedCanon == CanonType.movie,
                localTitleCount: selectedCanon == CanonType.movie ? moviesCount : seriesCount,
              ),

              const SizedBox(height: 16),

              // 3. TOP 3 SHOWCASE ROW — pinned titles (Edit Profile) first, then top ranks.
              TopShowcaseRow(
                topEntries: _showcase(entries, ref.watch(myPinnedShowcaseProvider).valueOrNull ?? const []),
                onTapEntry: handleTap,
              ),

              const SizedBox(height: 16),

              // 4. SUB-HEADER: VIEW SWITCHER (FE-207) & FRANCHISE ROLLUP TOGGLE (FE-208)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // View Mode Switcher
                    Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: TellyColors.cardOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TellyColors.strokeOf(context)),
                      ),
                      child: Row(
                        children: [
                          _buildViewModeButton(
                            context: context,
                            key: const Key('view_mode_ranked_button'),
                            icon: Icons.format_list_numbered_rounded,
                            label: 'Ranked',
                            isSelected: viewMode == CanonViewMode.rankedList,
                            onTap: () {
                              ref.read(hapticsServiceProvider).duelSelectCandidate();
                              ref.read(canonViewModeProvider.notifier).select(CanonViewMode.rankedList);
                            },
                          ),
                          _buildViewModeButton(
                            context: context,
                            key: const Key('view_mode_tier_button'),
                            icon: Icons.view_agenda_rounded,
                            label: 'Tiers',
                            isSelected: viewMode == CanonViewMode.tierView,
                            onTap: () {
                              ref.read(hapticsServiceProvider).duelSelectCandidate();
                              ref.read(canonViewModeProvider.notifier).select(CanonViewMode.tierView);
                            },
                          ),
                          _buildViewModeButton(
                            context: context,
                            key: const Key('view_mode_grid_button'),
                            icon: Icons.grid_view_rounded,
                            label: '3x3',
                            isSelected: viewMode == CanonViewMode.grid3x3,
                            onTap: () {
                              ref.read(hapticsServiceProvider).duelSelectCandidate();
                              ref.read(canonViewModeProvider.notifier).select(CanonViewMode.grid3x3);
                            },
                          ),
                        ],
                      ),
                    ),

                    // View Options Overflow Button (relocated Rollup & preferences)
                    IconButton(
                      key: const Key('canon_options_button'),
                      icon: Icon(Icons.more_vert, color: TellyColors.textSecondaryOf(context)),
                      tooltip: 'View Options',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: TellyColors.cardOf(context),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (sheetCtx) => Consumer(
                            builder: (ctx, ref, _) {
                              final currentRollup = ref.watch(franchiseRollupProvider);
                              return SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'VIEW OPTIONS',
                                        style: TellyTypography.labelSmall(color: TellyColors.textTertiaryOf(context))
                                            .copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                      ),
                                      const SizedBox(height: 12),
                                      if (selectedCanon == CanonType.series)
                                        SwitchListTile(
                                          key: const Key('franchise_rollup_toggle'),
                                          contentPadding: EdgeInsets.zero,
                                          title: Text('Anime Franchise Rollup', style: TextStyle(color: TellyColors.textPrimaryOf(context))),
                                          subtitle: Text(
                                            'Combine multi-season anime into a single master entry',
                                            style: TextStyle(color: TellyColors.textTertiaryOf(context), fontSize: 12),
                                          ),
                                          activeThumbColor: TellyColors.primaryAccentOf(context),
                                          value: currentRollup,
                                          onChanged: (val) {
                                            ref.read(hapticsServiceProvider).duelSelectCandidate();
                                            ref.read(franchiseRollupProvider.notifier).select(val);
                                          },
                                        )
                                      else
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Text('No additional options for Movies.', style: TextStyle(color: TellyColors.textTertiaryOf(context))),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 5. VIEW MODE CONTENT (FE-207, FE-ALGO-02)
              switch (viewMode) {
                CanonViewMode.rankedList => RankedCanonList(
                    entries: entries,
                    onTapEntry: handleTap,
                    onLongPressEntry: (entry) => _showEntryActions(context, entry, ref, selectedCanon),
                  ),
                CanonViewMode.tierView => TierViewList(
                    entries: entries,
                    onTapEntry: handleTap,
                  ),
                CanonViewMode.grid3x3 => PosterGridView(
                    entries: entries,
                    onTapEntry: handleTap,
                  ),
              },

              // End space lets the last row scroll above the floating Log button (#44).
              const SizedBox(height: 32 + TellyLogFab.clearance),
            ],
          ),
        ),
      ),
    ),
  );
  }

  /// Up to three titles: my pinned picks that belong to the shown canon (in pin order),
  /// then the canon's best-ranked titles that are not already pinned.
  static List<CanonEntry> _showcase(List<CanonEntry> entries, List<ShowcasePick> pinned) {
    final picked = <CanonEntry>[
      for (final p in pinned)
        ...entries.where((e) => e.id == p.titleId && e.mediaType == p.mediaType).take(1),
    ];
    return [...picked, ...entries.where((e) => !picked.contains(e))].take(3).toList();
  }

  /// Row context menu: "Reset Duels for This Show" re-runs the tournament for the title
  /// (features/02 §7.2); "Remove from List" deletes the entry and rescores the canon.
  Future<void> _showEntryActions(BuildContext context, CanonEntry entry, WidgetRef ref, CanonType selectedCanon) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TellyColors.cardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('reset_duels_action'),
              leading: const Icon(Icons.refresh, color: TellyColors.phosphorLime),
              title: Text('Re-duel & Recalibrate Rank', style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))),
              subtitle: Text(
                'Play comparison duels to organically calibrate position',
                style: TextStyle(color: TellyColors.textTertiaryOf(context), fontSize: 12),
              ),
              onTap: () => Navigator.of(ctx).pop('reset'),
            ),
            ListTile(
              key: const Key('remove_title_action'),
              leading: const Icon(Icons.delete_outline, color: TellyColors.neonCoral),
              title: Text('Remove from List', style: TellyTypography.bodyLarge(color: TellyColors.neonCoral)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    if (action == 'reset') {
      context.push(
        Routes.log,
        extra: TitleSearchResult(id: entry.id, mediaType: entry.mediaType, title: entry.title, posterPath: entry.posterPath),
      );
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: TellyColors.cardOf(context),
          title: Text('Remove from List?', style: TextStyle(color: TellyColors.textPrimaryOf(context))),
          content: Text(
            'Are you sure you want to remove "${entry.title}"? Your remaining rankings and scores will be recalculated automatically.',
            style: TextStyle(color: TellyColors.textSecondaryOf(context)),
          ),
          actions: [
            TextButton(
              key: const Key('cancel_delete_title_button'),
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirm_delete_title_button'),
              style: TextButton.styleFrom(foregroundColor: TellyColors.neonCoral),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        await ref.read(profileCanonProvider.notifier).deleteTitle(
          canon: selectedCanon,
          titleId: entry.id,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${entry.title}" from your list'),
              backgroundColor: TellyColors.cardOf(context),
            ),
          );
        }
      }
    }
  }

  Widget _buildViewModeButton({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? TellyColors.surfaceOf(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: TellyColors.borderGlassOf(context)) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? TellyColors.primaryAccentOf(context) : TellyColors.textPrimaryOf(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TellyTypography.labelSmall(
                color: isSelected ? TellyColors.primaryAccentOf(context) : TellyColors.textPrimaryOf(context),
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
