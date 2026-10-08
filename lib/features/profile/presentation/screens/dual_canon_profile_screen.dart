import 'package:flutter/material.dart';
import 'package:telly_app/core/widgets/telly_log_fab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_canon_switcher.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../levels/presentation/controllers/rewards_controller.dart';
import '../../../levels/presentation/widgets/reward_cosmetics.dart';
import '../../../logging/domain/title_search_result.dart';
import '../../../ranking/domain/canon_type.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';
import '../../data/profile_share_service.dart';
import '../controllers/edit_profile_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/canon_podium.dart';
import '../widgets/canon_stats_panel.dart';
import '../widgets/poster_grid_view.dart';
import '../widgets/ranked_canon_list.dart';
import '../widgets/tier_view_list.dart';
import '../widgets/top_showcase_row.dart';

/// SCR-14 Canon tab: the compact Movies / TV Shows switcher, then the selected view.
/// Stats and the view choice live in header sheets (epic #47, decision 0004); the profile
/// card lives in the More hub.
/// Conforms to:
/// - `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §14 (SCR-14)
/// - `docs/features/06_PROFILE_THE_CANON_AND_STATS.md` §2–§3
/// - `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §2
/// - `docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md` §2
class DualCanonProfileScreen extends ConsumerWidget {
  final VoidCallback? onShareTap;
  final ValueChanged<CanonEntry>? onTapEntry;

  const DualCanonProfileScreen({
    super.key,
    this.onShareTap,
    this.onTapEntry,
  });

  static const _viewIcons = {
    CanonViewMode.rankedList: Icons.format_list_numbered_rounded,
    CanonViewMode.tierView: Icons.view_agenda_rounded,
    CanonViewMode.grid3x3: Icons.grid_view_rounded,
  };

  static const _viewNames = {
    CanonViewMode.rankedList: 'Ranked',
    CanonViewMode.tierView: 'Tiers',
    CanonViewMode.grid3x3: '3x3',
  };

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
          // FE-HEADER-01 tab header; Stats and View open sheets (#47), Settings sits in More (#44).
          header: TellyScreenHeader(
            title: 'Canon',
            actions: [
              TellyHeaderAction(
                key: const Key('canon_stats_button'),
                icon: Icons.insights_rounded,
                tooltip: 'Stats',
                onPressed: () => _showStatsSheet(context, handleTap),
              ),
              TellyHeaderAction(
                key: const Key('canon_view_button'),
                icon: _viewIcons[viewMode]!,
                tooltip: 'View: ${_viewNames[viewMode]}',
                onPressed: () => _showViewSheet(context),
              ),
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
                // My header art, the level 30 reward (features/10 §5.2, #148).
                HeaderArtBanner(userId: me?.id, margin: const EdgeInsets.fromLTRB(16, 0, 16, 12)),
                // The shared compact switcher (component library §5.5).
                TellyCanonSwitcher(
                  selected: selectedCanon == CanonType.movie ? 'movie' : 'tv',
                  movieCount: moviesCount,
                  seriesCount: seriesCount,
                  movieKey: const Key('movie_canon_tab'),
                  seriesKey: const Key('series_canon_tab'),
                  onSelect: (mediaType) {
                    ref.read(hapticsServiceProvider).duelSelectCandidate();
                    ref.read(selectedCanonProvider.notifier).select(mediaType == 'movie' ? CanonType.movie : CanonType.series);
                  },
                ),

                const SizedBox(height: 12),

                switch (viewMode) {
                  // Ranked: #1–#3 on the podium, rows from #4 (#47). An empty canon keeps the list's empty state.
                  CanonViewMode.rankedList when entries.isEmpty => const RankedCanonList(entries: []),
                  CanonViewMode.rankedList => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CanonPodium(
                          entries: entries,
                          onTapEntry: handleTap,
                          onLongPressEntry: (entry) => _showEntryActions(context, entry, ref, selectedCanon),
                          // #147: gold rank tags once the level 15 reward is equipped.
                          goldTags: ref.watch(goldPodiumProvider),
                        ),
                        if (entries.length > 3) ...[
                          const SizedBox(height: 8),
                          RankedCanonList(
                            entries: entries.skip(3).toList(),
                            onTapEntry: handleTap,
                            onLongPressEntry: (entry) => _showEntryActions(context, entry, ref, selectedCanon),
                          ),
                        ],
                      ],
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

  static Widget _sheetLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TellyTypography.labelSmall(color: TellyColors.textTertiaryOf(context))
              .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
        ),
      );

  /// SCR-14 View sheet: Ranked / Tiers / 3x3, plus the Series-only franchise rollup.
  void _showViewSheet(BuildContext context) {
    TellyFrostedSheet.show<void>(
      context: context,
      builder: (sheetCtx) => Consumer(
        builder: (ctx, ref, _) {
          final current = ref.watch(canonViewModeProvider);
          final isSeries = ref.watch(selectedCanonProvider) == CanonType.series;
          Widget option(CanonViewMode mode, Key key, String label) {
            final isSelected = current == mode;
            return ListTile(
              key: key,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_viewIcons[mode], color: TellyColors.textSecondaryOf(ctx)),
              title: Text(label, style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(ctx))),
              trailing: isSelected ? Icon(Icons.check_rounded, color: TellyColors.primaryAccentOf(ctx)) : null,
              selected: isSelected,
              onTap: () {
                ref.read(hapticsServiceProvider).duelSelectCandidate();
                ref.read(canonViewModeProvider.notifier).select(mode);
                Navigator.of(sheetCtx).pop();
              },
            );
          }

          return Column(
            key: const Key('canon_view_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetLabel(ctx, 'VIEW'),
              option(CanonViewMode.rankedList, const Key('view_mode_ranked_button'), 'Ranked'),
              option(CanonViewMode.tierView, const Key('view_mode_tier_button'), 'Tiers'),
              option(CanonViewMode.grid3x3, const Key('view_mode_grid_button'), '3x3 grid'),
              if (isSeries) ...[
                const SizedBox(height: 12),
                _sheetLabel(ctx, 'SERIES ONLY'),
                SwitchListTile(
                  key: const Key('franchise_rollup_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('Anime franchise rollup', style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(ctx))),
                  subtitle: Text(
                    'Combine multi-season anime into one entry',
                    style: TellyTypography.caption(color: TellyColors.textTertiaryOf(ctx)),
                  ),
                  activeThumbColor: TellyColors.primaryAccentOf(ctx),
                  value: ref.watch(franchiseRollupProvider),
                  onChanged: (val) {
                    ref.read(hapticsServiceProvider).duelSelectCandidate();
                    ref.read(franchiseRollupProvider.notifier).select(val);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// SCR-14 Stats sheet: the selected canon's stats tiles, then the Top 3 showcase.
  void _showStatsSheet(BuildContext context, ValueChanged<CanonEntry> onTapEntry) {
    TellyFrostedSheet.show<void>(
      context: context,
      // The stats panel and showcase row carry their own 16 dp gutters.
      padding: const EdgeInsets.only(bottom: 12),
      builder: (sheetCtx) => Consumer(
        builder: (ctx, ref, _) {
          final canon = ref.watch(selectedCanonProvider);
          final isMovie = canon == CanonType.movie;
          final entries = ref.watch(profileCanonProvider).entriesFor(canon, rollupAnime: ref.watch(franchiseRollupProvider));
          return Column(
            key: const Key('canon_stats_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _sheetLabel(ctx, isMovie ? 'MOVIE STATS' : 'TV STATS'),
              ),
              CanonStatsPanel(
                stats: ref.watch(canonStatsProvider(canon)).valueOrNull,
                isMovie: isMovie,
                localTitleCount: entries.length,
              ),
              const SizedBox(height: 16),
              // Carries its own "TOP 3 SHOWCASE" section header.
              TopShowcaseRow(
                topEntries: _showcase(entries, ref.watch(myPinnedShowcaseProvider).valueOrNull ?? const []),
                onTapEntry: (entry) {
                  Navigator.of(sheetCtx).pop();
                  onTapEntry(entry);
                },
              ),
            ],
          );
        },
      ),
    );
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
}
