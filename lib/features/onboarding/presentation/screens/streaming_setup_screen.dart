import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/routes.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';

class StreamingProviderItem {
  final String id;
  final String name;
  final String tag;
  final IconData icon;

  const StreamingProviderItem({
    required this.id,
    required this.name,
    required this.tag,
    required this.icon,
  });
}

const kDefaultStreamingProviders = [
  StreamingProviderItem(id: 'netflix', name: 'Netflix', tag: 'Top Series & Films', icon: Icons.movie_outlined),
  StreamingProviderItem(id: 'max', name: 'Max', tag: 'HBO Originals & Classics', icon: Icons.tv_outlined),
  StreamingProviderItem(id: 'apple_tv', name: 'Apple TV+', tag: 'Prestige Sci-Fi & Dramas', icon: Icons.apple),
  StreamingProviderItem(id: 'hulu', name: 'Hulu', tag: 'FX Hits & Next-Day TV', icon: Icons.live_tv_outlined),
  StreamingProviderItem(id: 'disney_plus', name: 'Disney+', tag: 'Star Wars, Marvel & Pixar', icon: Icons.auto_awesome_outlined),
  StreamingProviderItem(id: 'prime_video', name: 'Prime Video', tag: 'Amazon Originals', icon: Icons.play_circle_outline),
  StreamingProviderItem(id: 'crunchyroll', name: 'Crunchyroll', tag: 'Simulcasts & Classic Anime', icon: Icons.video_collection_outlined),
  StreamingProviderItem(id: 'paramount_plus', name: 'Paramount+', tag: 'Yellowstone, Showtime & Trek', icon: Icons.star_border_outlined),
];

final selectedProvidersProvider = StateProvider<Set<String>>((ref) => {
      'netflix',
      'max',
      'apple_tv',
    });

final includeFreePlatformsProvider = StateProvider<bool>((ref) => false);

/// SCR-02: Streaming Provider Household Setup Screen.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §2 (`SCR-02`).
class StreamingSetupScreen extends ConsumerWidget {
  const StreamingSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProvidersProvider);
    final includeFree = ref.watch(includeFreePlatformsProvider);

    void toggleProvider(String id) {
      final updated = Set<String>.from(selected);
      if (updated.contains(id)) {
        updated.remove(id);
      } else {
        updated.add(id);
      }
      ref.read(selectedProvidersProvider.notifier).state = updated;
    }

    void navigateForward() => context.go(Routes.seedGrid);

    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('STEP 2 OF 3', style: TellyTypography.caption(color: TellyColors.textTertiary)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Where do you watch?', style: TellyTypography.displayXL()),
                    const SizedBox(height: 8),
                    Text(
                      'Select your active subscriptions so we can tailor streaming badges and co-watching recommendations.',
                      style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
                    ),
                    const SizedBox(height: 24),

                    // 2-Column Grid of Providers
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kDefaultStreamingProviders.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                      ),
                      itemBuilder: (context, index) {
                        final provider = kDefaultStreamingProviders[index];
                        final isSelected = selected.contains(provider.id);

                        return GestureDetector(
                          onTap: () => toggleProvider(provider.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected ? TellyColors.backgroundCard : TellyColors.backgroundSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? TellyColors.phosphorLime : TellyColors.strokeSubtle,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: TellyColors.phosphorLime.withValues(alpha: 0.15),
                                        blurRadius: 12.0,
                                      ),
                                    ]
                                  : null,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      provider.icon,
                                      color: isSelected ? TellyColors.phosphorLime : TellyColors.textSecondary,
                                      size: 24,
                                    ),
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? TellyColors.phosphorLime : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? TellyColors.phosphorLime : TellyColors.strokeStrong,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 14, color: Colors.black)
                                          : null,
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.name,
                                      style: TellyTypography.titleMedium(
                                        color: isSelected ? Colors.white : TellyColors.textSecondary,
                                      ).copyWith(fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.tag,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TellyTypography.caption(color: TellyColors.textTertiary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Include free platforms checkbox
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        ref.read(includeFreePlatformsProvider.notifier).state = !includeFree;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: includeFree,
                              activeColor: TellyColors.phosphorLime,
                              checkColor: Colors.black,
                              onChanged: (val) {
                                ref.read(includeFreePlatformsProvider.notifier).state = val ?? false;
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Include free platforms (Tubi, Pluto, Kanopy)',
                                style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA
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
                    label: selected.isNotEmpty
                        ? 'CONTINUE (${selected.length} SELECTED) →'
                        : 'CONTINUE →',
                    onPressed: navigateForward,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: navigateForward,
                    child: Text(
                      "I don't have streaming services / Skip for now",
                      style: TellyTypography.caption(color: TellyColors.textTertiary),
                    ),
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
