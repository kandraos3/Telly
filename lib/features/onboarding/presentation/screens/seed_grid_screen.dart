import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../data/canon_import_service.dart';
import '../../data/top_50_seeds.dart';
import '../controllers/onboarding_controllers.dart';

/// Picks a Letterboxd export and returns its text, or null if cancelled (FE-606).
final csvFilePickerProvider = Provider<Future<String?> Function()>((ref) => () async {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      final bytes = picked?.files.single.bytes;
      return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
    });

/// SCR-03: Movie, Series & Anime Recognition Seed Grid Screen.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §3 (`SCR-03`)
/// and `docs/features/01_ONBOARDING_AND_TASTE_SEEDING.md` §3.
class SeedGridScreen extends ConsumerWidget {
  const SeedGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(seedSelectionProvider);
    final controller = ref.read(seedSelectionProvider.notifier);
    final currentFilter = selection.filter;

    bool matches(SeedTitle t, SeedFilter f) => switch (f) {
          SeedFilter.all => true,
          SeedFilter.movie => t.mediaType == 'movie',
          SeedFilter.tv => t.mediaType == 'tv' && !t.isAnime,
          SeedFilter.anime => t.isAnime,
        };
    int countOf(SeedFilter f) => kTop50SeedTitles.where((t) => matches(t, f)).length;
    final filteredTitles = kTop50SeedTitles.where((t) => matches(t, currentFilter)).toList();

    final count = selection.selected.length;
    final canContinue = selection.canStart;
    const minimum = SeedSelectionState.minimumPicks;

    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('STEP 3 OF 3', style: TellyTypography.caption(color: TellyColors.textPrimary)),
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
                            "Tap movies, series & anime you've watched.",
                            style: TellyTypography.displayXL(),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select at least $minimum to calibrate your Movie and Series canons in a few quick duels.',
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
                                style:
                                    TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(fontSize: 14),
                              ),
                              subtitle: Text(
                                'Upload diary.csv or sync public profile',
                                style: TellyTypography.caption(color: TellyColors.textTertiary),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: TellyColors.textTertiary),
                              key: const Key('import_letterboxd'),
                              onTap: () => _importLetterboxd(context, ref),
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
                                style:
                                    TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(fontSize: 14),
                              ),
                              subtitle: Text(
                                'Instant username sync without password',
                                style: TellyTypography.caption(color: TellyColors.textTertiary),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: TellyColors.textTertiary),
                              key: const Key('import_anilist'),
                              onTap: () => _importAniList(context, ref),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category filter chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'All (${countOf(SeedFilter.all)})',
                                  isSelected: currentFilter == SeedFilter.all,
                                  onSelected: () => controller.setFilter(SeedFilter.all),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: '🎬 Movies (${countOf(SeedFilter.movie)})',
                                  isSelected: currentFilter == SeedFilter.movie,
                                  onSelected: () => controller.setFilter(SeedFilter.movie),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: '📺 Series (${countOf(SeedFilter.tv)})',
                                  isSelected: currentFilter == SeedFilter.tv,
                                  onSelected: () => controller.setFilter(SeedFilter.tv),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: '⚡ Anime (${countOf(SeedFilter.anime)})',
                                  isSelected: currentFilter == SeedFilter.anime,
                                  onSelected: () => controller.setFilter(SeedFilter.anime),
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
                          final isSelected = selection.selected.contains(seedKey(item));

                          return GestureDetector(
                            key: ValueKey('seed_card_${item.mediaType}_${item.id}'),
                            onTap: () => controller.toggle(item),
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
                                  // Poster (cached, shimmer while loading); the title card is the fallback.
                                  PosterImage(
                                    posterPath: item.posterPath,
                                    fallback: Container(
                                      color: TellyColors.backgroundSurface,
                                      padding: const EdgeInsets.all(6),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item.mediaType == 'movie' ? '🎬' : (item.isAnime ? '⛩️' : '📺'),
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
                                            style: TellyTypography.caption(color: TellyColors.textTertiary)
                                                .copyWith(fontSize: 10),
                                          ),
                                        ],
                                      ),
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
                  if (selection.imported > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${selection.imported} imported titles are already in your canons',
                        key: const Key('imported_count_text'),
                        style: TellyTypography.caption(color: TellyColors.phosphorLime),
                      ),
                    ),
                  TellyPrimaryButton(
                    key: const Key('start_duels_button'),
                    label: canContinue
                        ? 'Start Ranking Duels →'
                        : 'Select at least $minimum titles ($count/$minimum selected)',
                    onPressed: canContinue ? () => context.go(Routes.tournament) : null,
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

Future<void> _importLetterboxd(BuildContext context, WidgetRef ref) async {
  final csv = await ref.read(csvFilePickerProvider)();
  if (csv == null || !context.mounted) return;
  await _runImport(context, ref, () => ref.read(canonImportServiceProvider).importLetterboxd(csv));
}

Future<void> _importAniList(BuildContext context, WidgetRef ref) async {
  final username = await showDialog<String>(context: context, builder: (_) => const _AniListUsernameDialog());
  if (username == null || username.isEmpty || !context.mounted) return;
  await _runImport(context, ref, () async {
    final entries = await ref.read(aniListImporterProvider).fetchUserAnime(username);
    return ref.read(canonImportServiceProvider).importAniList(entries);
  });
}

Future<void> _runImport(BuildContext context, WidgetRef ref, Future<ImportResult> Function() run) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await run();
    ref.read(seedSelectionProvider.notifier).recordImport(result.added);
    final skipped = result.unmatched.isEmpty ? '' : ' (${result.unmatched.length} not found)';
    messenger.showSnackBar(SnackBar(content: Text('Imported ${result.added} titles$skipped')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

/// Owns its controller so it outlives the dialog's exit animation.
class _AniListUsernameDialog extends StatefulWidget {
  const _AniListUsernameDialog();

  @override
  State<_AniListUsernameDialog> createState() => _AniListUsernameDialogState();
}

class _AniListUsernameDialogState extends State<_AniListUsernameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TellyColors.backgroundCard,
      title: Text('AniList username', style: TellyTypography.titleMedium()),
      content: TextField(
        key: const Key('anilist_username_field'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. frieren_fan'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          key: const Key('anilist_import_confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Import'),
        ),
      ],
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
