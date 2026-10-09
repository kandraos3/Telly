import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../ranking/domain/franchise_rollup_service.dart';
import '../../../ranking/presentation/screens/duel_arena_screen.dart';
import '../../../sharing/data/story_share_service.dart';
import '../../domain/onboarding_tournament.dart';
import '../controllers/onboarding_controllers.dart';

/// `SCR-04` Onboarding Duel Tournament & Starter Canon Reveal (FE-606).
class OnboardingTournamentScreen extends ConsumerWidget {
  const OnboardingTournamentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingTournamentProvider);
    if (state.done) return const StarterCanonReveal();
    if (state.error != null) {
      return Scaffold(
        backgroundColor: TellyColors.canvasOf(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error!, textAlign: TextAlign.center, style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))),
                const SizedBox(height: 16),
                TellyPrimaryButton(
                  label: 'TRY AGAIN',
                  onPressed: () => ref.invalidate(onboardingTournamentProvider),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return DuelArenaScreen.custom(
      state: onboardingTournamentProvider.select((s) => s.duel),
      actions: onboardingTournamentProvider.notifier,
      progressLabel: (a) => OnboardingDuel.label(a.candidate.mediaType, a.step, a.totalEstimatedSteps),
      tieLabel: 'Too different / Hard to say',
      onCancel: () => context.go(Routes.seedGrid),
    );
  }
}

/// "Dual Canons Unveiled" (features/01 Screen 5): confetti, Top 5 per canon, finish.
class StarterCanonReveal extends ConsumerStatefulWidget {
  const StarterCanonReveal({super.key});

  @override
  ConsumerState<StarterCanonReveal> createState() => _StarterCanonRevealState();
}

class _StarterCanonRevealState extends ConsumerState<StarterCanonReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  String? _canon; // null until the user picks; defaults to the first non-empty canon
  bool _finishing = false;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _share(List<CanonEntry> top, String label) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(storyShareServiceProvider).shareStarterCanon(
            canonLabel: label,
            topTitles: [for (final e in top) e.title],
          );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      // The router leaves onboarding as soon as the profile reports completion.
      await ref.read(authControllerProvider.notifier).finishOnboarding();
    } catch (_) {
      if (mounted) {
        setState(() => _finishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't finish onboarding. Check your connection and try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canons = ref.watch(profileCanonProvider);
    final canon = _canon ?? (canons.movies.isNotEmpty || canons.series.isEmpty ? 'movie' : 'tv');
    final top = (canon == 'movie' ? canons.movies : canons.series).take(5).toList();
    final label = canon == 'movie' ? 'Top Movies' : 'Top Series & Anime';

    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Your Rankings, Unveiled', style: TellyTypography.displayXL(color: TellyColors.textPrimaryOf(context)), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _CanonToggle(
                        key: const Key('reveal_toggle_movie'),
                        label: '🎬 Top Movies',
                        selected: canon == 'movie',
                        onTap: () => setState(() => _canon = 'movie'),
                      ),
                      const SizedBox(width: 8),
                      _CanonToggle(
                        key: const Key('reveal_toggle_tv'),
                        label: '📺 Top Series & Anime',
                        selected: canon == 'tv',
                        onTap: () => setState(() => _canon = 'tv'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: top.isEmpty
                        ? Center(
                            child: Text('Nothing ranked in this list yet.', style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))),
                          )
                        : ListView(
                            children: [for (final e in top) _RevealRow(entry: e)],
                          ),
                  ),
                  TellyPrimaryButton(
                    key: const Key('finish_onboarding_button'),
                    label: 'Add Friends & Finish',
                    isLoading: _finishing,
                    onPressed: _finishing ? null : _finish,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('share_starter_canon_button'),
                    onPressed: top.isEmpty ? null : () => _share(top, label),
                    child: Text('Share to Instagram Story',
                        style: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context))),
                  ),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (_, __) => CustomPaint(
                key: const Key('confetti_burst'),
                size: Size.infinite,
                painter: _ConfettiPainter(_confetti.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanonToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CanonToggle({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? TellyColors.phosphorLime : TellyColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? TellyColors.phosphorLime : TellyColors.strokeSubtleOf(context)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TellyTypography.labelMedium(color: selected ? Colors.black : TellyColors.textSecondaryOf(context)),
          ),
        ),
      ),
    );
  }
}

class _RevealRow extends StatelessWidget {
  final CanonEntry entry;
  const _RevealRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final first = entry.rankPosition == 1;
    return Container(
      key: Key('reveal_row_${entry.rankPosition}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TellyColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        // #1 gets the gold-foil border (features/01 Screen 5).
        border: Border.all(color: first ? TellyColors.warmAmber : TellyColors.strokeSubtleOf(context), width: first ? 2 : 1),
      ),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('#${entry.rankPosition}', style: TellyTypography.scoreChip(color: TellyColors.textSecondaryOf(context)))),
          Expanded(child: Text(entry.title, style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)), overflow: TextOverflow.ellipsis)),
          Text(
            entry.calculatedScore.toStringAsFixed(2),
            style: TellyTypography.scoreMono(color: first ? TellyColors.warmAmber : TellyColors.phosphorLime),
          ),
        ],
      ),
    );
  }
}

/// A one-shot burst of style-guide-colored confetti falling from the top.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;

  static const _colors = [
    TellyColors.phosphorLime,
    TellyColors.warmAmber,
    TellyColors.electricViolet,
    TellyColors.neonCoral,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1 || size.isEmpty) return;
    final random = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 60; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.6 + random.nextDouble() * 0.6;
      final y = -20 + t * speed * size.height;
      paint.color = _colors[i % _colors.length].withValues(alpha: 1 - t);
      canvas.save();
      canvas.translate(x + math.sin(t * 6 + i) * 12, y);
      canvas.rotate(t * 8 + i);
      canvas.drawRect(const Rect.fromLTWH(-4, -2, 8, 4), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
