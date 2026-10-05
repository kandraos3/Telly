import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../logging/domain/title_search_result.dart';
import '../../../ranking/domain/canon_type.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';
import '../../data/profile_share_service.dart';
import '../controllers/edit_profile_controller.dart';
import '../controllers/profile_controller.dart';
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
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSquadsTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onAvatarTap;
  final ValueChanged<CanonEntry>? onTapEntry;

  const DualCanonProfileScreen({
    super.key,
    this.onSettingsTap,
    this.onSquadsTap,
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

    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      body: SafeArea(
        child: GestureDetector(
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // 1. PROFILE HEADER CARD (Avatar, Handle, Bio, Stats)
                ProfileHeaderCard(
                  displayName: me?.displayName ?? '',
                  handle: me?.username == null ? '' : '@${me!.username}',
                  bio: me?.bio,
                  avatarUrl: me?.avatarUrl,
                  movieCount: moviesCount,
                  seriesCount: seriesCount,
                  onSettingsTap: onSettingsTap,
                  onSquadsTap: onSquadsTap,
                  onShareTap: onShareTap ??
                      () => ref.read(profileShareServiceProvider).shareProfile(
                            handle: me?.username ?? '',
                            displayName: me?.displayName ?? '',
                            topMovies: [for (final e in canonState.movies) e.title],
                            topSeries: [for (final e in canonState.series) e.title],
                          ),
                  onAvatarTap: onAvatarTap ?? () => context.push(Routes.editProfile),
                ),

                const SizedBox(height: 16),

                // 2. SEGMENTED DUAL-CANON SELECTOR (FE-206)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: TellyColors.backgroundSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TellyColors.borderGlass),
                    ),
                    child: Row(
                      children: [
                        // Movie Canon Tab
                        Expanded(
                          child: _buildCanonTab(
                            key: const Key('movie_canon_tab'),
                            label: 'Movies ($moviesCount)',
                            isSelected: selectedCanon == CanonType.movie,
                            onTap: () {
                              ref.read(hapticsServiceProvider).duelSelectCandidate();
                              ref.read(selectedCanonProvider.notifier).select(CanonType.movie);
                            },
                          ),
                        ),

                        const SizedBox(width: 4),

                        // Series Canon Tab
                        Expanded(
                          child: _buildCanonTab(
                            key: const Key('series_canon_tab'),
                            label: 'TV Shows ($seriesCount)',
                            subtitle: 'Includes anime',
                            isSelected: selectedCanon == CanonType.series,
                            onTap: () {
                              ref.read(hapticsServiceProvider).duelSelectCandidate();
                              ref.read(selectedCanonProvider.notifier).select(CanonType.series);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        color: TellyColors.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TellyColors.strokeSubtle),
                      ),
                      child: Row(
                        children: [
                          _buildViewModeButton(
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
                      icon: const Icon(Icons.more_vert, color: TellyColors.textSecondary),
                      tooltip: 'View Options',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: TellyColors.backgroundCard,
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
                                        style: TellyTypography.labelSmall(color: TellyColors.textTertiary)
                                            .copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                      ),
                                      const SizedBox(height: 12),
                                      if (selectedCanon == CanonType.series)
                                        SwitchListTile(
                                          key: const Key('franchise_rollup_toggle'),
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Anime Franchise Rollup', style: TextStyle(color: TellyColors.textPrimary)),
                                          subtitle: const Text(
                                            'Combine multi-season anime into a single master entry',
                                            style: TextStyle(color: TellyColors.textTertiary, fontSize: 12),
                                          ),
                                          activeThumbColor: TellyColors.phosphorLime,
                                          value: currentRollup,
                                          onChanged: (val) {
                                            ref.read(hapticsServiceProvider).duelSelectCandidate();
                                            ref.read(franchiseRollupProvider.notifier).select(val);
                                          },
                                        )
                                      else
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          child: Text('No additional options for Movies.', style: TextStyle(color: TellyColors.textTertiary)),
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

              const SizedBox(height: 32),
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
      backgroundColor: TellyColors.backgroundCard,
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
              title: Text('Re-duel & Recalibrate Rank', style: TellyTypography.bodyLarge()),
              subtitle: const Text(
                'Play comparison duels to organically calibrate position',
                style: TextStyle(color: TellyColors.textTertiary, fontSize: 12),
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
          backgroundColor: TellyColors.backgroundCard,
          title: const Text('Remove from List?', style: TextStyle(color: TellyColors.textPrimary)),
          content: Text(
            'Are you sure you want to remove "${entry.title}"? Your remaining rankings and scores will be recalculated automatically.',
            style: const TextStyle(color: TellyColors.textSecondary),
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
              backgroundColor: TellyColors.backgroundCard,
            ),
          );
        }
      }
    }
  }

  Widget _buildCanonTab({
    required Key key,
    required String label,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? TellyColors.phosphorLime : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: TellyColors.phosphorLime.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TellyTypography.labelSmall(
                color: isSelected ? const Color(0xFF08090C) : TellyColors.textSecondary,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF08090C).withValues(alpha: 0.7) : TellyColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeButton({
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
          color: isSelected ? TellyColors.backgroundSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: TellyColors.borderGlass) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? TellyColors.phosphorLime : TellyColors.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TellyTypography.caption(
                color: TellyColors.textPrimary,
              ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
