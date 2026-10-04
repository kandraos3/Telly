import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/routes.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../data/top_50_seeds.dart';

final selectedSeedTitlesProvider = StateProvider<Set<int>>((ref) => <int>{});
final seedCategoryFilterProvider = StateProvider<String>((ref) => 'all');

/// SCR-03: Movie, Series & Anime Recognition Seed Grid Screen.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §3 (`SCR-03`)
/// and `docs/features/01_ONBOARDING_AND_TASTE_SEEDING.md` §3.
class SeedGridScreen extends ConsumerWidget {
  const SeedGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectedSeedTitlesProvider);
    final currentFilter = ref.watch(seedCategoryFilterProvider);

    final filteredTitles = kTop50SeedTitles.where((title) {
      if (currentFilter == 'movie') {
        return title.mediaType == 'movie';
      }
      if (currentFilter == 'tv') {
        return title.mediaType == 'tv' && !title.isAnime;
      }
      if (currentFilter == 'anime') {
        return title.isAnime;
      }
      return true;
    }).toList();

    final count = selectedIds.length;
    final canContinue = count >= 5;

    void toggleTitle(int id) {
      final updated = Set<int>.from(selectedIds);
      if (updated.contains(id)) {
        updated.remove(id);
      } else {
        updated.add(id);
      }
      ref.read(selectedSeedTitlesProvider.notifier).state = updated;
    }

    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('STEP 3 OF 3', style: TellyTypography.caption(color: TellyColors.textTertiary)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tap titles you have watched',
                            style: TellyTypography.displayXL(),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select at least 5 to seed your personal canon and kickstart initial pairwise duels.',
                            style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
                          ),
                          const SizedBox(height: 16),

                          // 1-Click Importer Buttons
                          Material(
                            color: TellyColors.backgroundCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: TellyColors.strokeSubtle),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: const Text('🎬', style: TextStyle(fontSize: 22)),
                              title: Text(
                                'Import from Letterboxd',
                                style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(fontSize: 14),
                              ),
                              subtitle: Text(
                                'Upload diary.csv or sync public profile',
                                style: TellyTypography.caption(color: TellyColors.textTertiary),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: TellyColors.textTertiary),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Letterboxd importer opened.')),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Material(
                            color: TellyColors.backgroundCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: TellyColors.strokeSubtle),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: const Text('⚡', style: TextStyle(fontSize: 22)),
                              title: Text(
                                'Import from AniList / MyAnimeList',
                                style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(fontSize: 14),
                              ),
                              subtitle: Text(
                                'Instant username sync without password',
                                style: TellyTypography.caption(color: TellyColors.textTertiary),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: TellyColors.textTertiary),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('AniList importer opened.')),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category filter chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'All (${kTop50SeedTitles.length})',
                                  isSelected: currentFilter == 'all',
                                  onSelected: () => ref.read(seedCategoryFilterProvider.notifier).state = 'all',
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: '🎬 Movies (15)',
                                  isSelected: currentFilter == 'movie',
                                  onSelected: () => ref.read(seedCategoryFilterProvider.notifier).state = 'movie',
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: '📺 TV Series (20)',
                                  isSelected: currentFilter == 'tv',
                                  onSelected: () => ref.read(seedCategoryFilterProvider.notifier).state = 'tv',
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: '⛩️ Anime (15)',
                                  isSelected: currentFilter == 'anime',
                                  onSelected: () => ref.read(seedCategoryFilterProvider.notifier).state = 'anime',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // 3-Column Poster Grid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = filteredTitles[index];
                          final isSelected = selectedIds.contains(item.id);

                          return GestureDetector(
                            key: ValueKey('seed_card_${item.id}'),
                            onTap: () => toggleTitle(item.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: TellyColors.backgroundCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? TellyColors.phosphorLime : TellyColors.strokeSubtle,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: TellyColors.phosphorLime.withValues(alpha: 0.25),
                                          blurRadius: 8.0,
                                        ),
                                      ]
                                    : null,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Poster Placeholder / Content
                                  Container(
                                    color: TellyColors.backgroundSurface,
                                    padding: const EdgeInsets.all(6),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.mediaType == 'movie'
                                              ? '🎬'
                                              : (item.isAnime ? '⛩️' : '📺'),
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.title,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TellyTypography.labelSmall().copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.releaseYear,
                                          style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Selected checkmark badge overlay
                                  if (isSelected)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: TellyColors.phosphorLime,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 15,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),

                                  // Canon indicator chip at bottom
                                  Positioned(
                                    bottom: 4,
                                    left: 4,
                                    right: 4,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.75),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.network,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 8, color: TellyColors.textSecondary),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: filteredTitles.length,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),

            // Bottom Sticky Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: TellyColors.backgroundPrimary,
                border: Border(top: BorderSide(color: TellyColors.strokeSubtle)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TellyPrimaryButton(
                    label: canContinue
                        ? 'BEGIN PAIRWISE DUELS ($count SELECTED) →'
                        : 'SELECT AT LEAST 5 TITLES ($count/5)',
                    onPressed: canContinue
                        ? () => context.go(Routes.tournament)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? TellyColors.phosphorLime : TellyColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? TellyColors.phosphorLime : TellyColors.strokeSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : TellyColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
