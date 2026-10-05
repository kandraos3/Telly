import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/routes.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../controllers/onboarding_controllers.dart';

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
  StreamingProviderItem(id: 'apple_tv_plus', name: 'Apple TV+', tag: 'Prestige Sci-Fi & Dramas', icon: Icons.apple),
  StreamingProviderItem(id: 'hulu', name: 'Hulu', tag: 'FX Hits & Next-Day TV', icon: Icons.live_tv_outlined),
  StreamingProviderItem(id: 'disney_plus', name: 'Disney+', tag: 'Star Wars, Marvel & Pixar', icon: Icons.auto_awesome_outlined),
  StreamingProviderItem(id: 'prime_video', name: 'Prime Video', tag: 'Amazon Originals', icon: Icons.play_circle_outline),
  StreamingProviderItem(id: 'crunchyroll', name: 'Crunchyroll', tag: 'Simulcasts & Classic Anime', icon: Icons.video_collection_outlined),
  StreamingProviderItem(id: 'paramount_plus', name: 'Paramount+', tag: 'Yellowstone, Showtime & Trek', icon: Icons.star_border_outlined),
  StreamingProviderItem(id: 'criterion', name: 'Criterion', tag: 'Arthouse & World Cinema', icon: Icons.theaters_outlined),
];

/// SCR-02: Streaming Provider Household Setup Screen.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §2 (`SCR-02`).
/// Ids match `public.streaming_platforms`; Continue saves to `user_streaming_subscriptions` (FE-606).
class StreamingSetupScreen extends ConsumerWidget {
  const StreamingSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(streamingSetupProvider);
    final controller = ref.read(streamingSetupProvider.notifier);
    final selected = setup.selected;
    final includeFree = setup.includeFree;

    void toggleProvider(String id) => controller.toggle(id);

    Future<void> navigateForward() async {
      if (!await controller.save()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(streamingSetupProvider).error!)));
        }
        return;
      }
      if (context.mounted) context.go(Routes.seedGrid);
    }

    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      appBar: AppBar(
        backgroundColor: TellyColors.canvasOf(context),
        title: Text('STEP 2 OF 3', style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context))),
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
                    Text('Where do you watch?', style: TellyTypography.displayXL(color: TellyColors.textPrimaryOf(context))),
                    const SizedBox(height: 8),
                    Text(
                      'Select your active subscriptions so we can tailor streaming badges and co-watching recommendations.',
                      style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
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
                              color: isSelected ? TellyColors.cardOf(context) : TellyColors.surfaceOf(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? TellyColors.phosphorLime : TellyColors.strokeSubtleOf(context),
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
                                      color: isSelected ? TellyColors.phosphorLime : TellyColors.textSecondaryOf(context),
                                      size: 24,
                                    ),
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? TellyColors.phosphorLime : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? TellyColors.phosphorLime : TellyColors.strokeSubtleOf(context),
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
                                        color: isSelected ? TellyColors.textPrimaryOf(context) : TellyColors.textSecondaryOf(context),
                                      ).copyWith(fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.tag,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
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
                        controller.setIncludeFree(!includeFree);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: includeFree,
                              semanticLabel: 'Include free platforms (Tubi, Pluto, Kanopy)',
                              activeColor: TellyColors.phosphorLime,
                              checkColor: Colors.black,
                              onChanged: (val) {
                                controller.setIncludeFree(val ?? false);
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Include free platforms (Tubi, Pluto, Kanopy)',
                                style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
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
              decoration: BoxDecoration(
                color: TellyColors.canvasOf(context),
                border: Border(top: BorderSide(color: TellyColors.strokeSubtleOf(context))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TellyPrimaryButton(
                    label: selected.isNotEmpty
                        ? 'CONTINUE (${selected.length} SELECTED) →'
                        : 'CONTINUE →',
                    isLoading: setup.saving,
                    onPressed: setup.saving ? null : navigateForward,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: setup.saving ? null : navigateForward,
                    child: Text(
                      "I don't have streaming services / Skip for now",
                      style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
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
