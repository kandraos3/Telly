import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../sharing/data/story_share_service.dart';
import '../../../sharing/domain/medal_story.dart';
import '../../domain/medal.dart';
import '../controllers/achievements_controller.dart';
import '../widgets/medal_badge.dart';
import '../widgets/medal_sheet.dart';

/// `SCR-24` Unlock moment (features/10 §9.4, mockup A3; #138): a full-screen celebration of
/// one unlock. Confetti (static when reduced motion is on), the "Achievement unlocked" chip,
/// the large medal, its name, a personal line, rarity and friends, then Pin to profile,
/// Share card and Done. A medium haptic fires on show.
class UnlockMomentScreen extends ConsumerStatefulWidget {
  final Medal medal;

  const UnlockMomentScreen({super.key, required this.medal});

  @override
  ConsumerState<UnlockMomentScreen> createState() => _UnlockMomentScreenState();
}

class _UnlockMomentScreenState extends ConsumerState<UnlockMomentScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(hapticsEnabledProvider)) HapticsService.mediumImpact();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: no confetti at all (a still frame would sit behind the text).
    if (MediaQuery.disableAnimationsOf(context)) {
      _confetti.value = 0;
    } else if (!_confetti.isAnimating && _confetti.value == 0) {
      _confetti.forward();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  /// The live medal (its pin changes while the moment is open).
  Medal get _medal =>
      ref.watch(achievementsControllerProvider).valueOrNull?.medals.where((m) => m.id == widget.medal.id).firstOrNull ??
      widget.medal;

  @override
  Widget build(BuildContext context) {
    final medal = _medal;
    final pinned = medal.pinnedSlot != null;
    final friends = medal.friendsCount;
    return Scaffold(
      key: const Key('unlock_moment'),
      backgroundColor: TellyColors.canvasOf(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: MediaQuery.disableAnimationsOf(context)
                  ? const SizedBox.shrink()
                  : AnimatedBuilder(
                      animation: _confetti,
                      builder: (_, __) =>
                          CustomPaint(painter: _ConfettiPainter(progress: _confetti.value, seed: medal.id.hashCode)),
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _Chip(label: 'Achievement unlocked'),
                  const SizedBox(height: 24),
                  MedalBadge.of(medal, size: MedalSize.large, describe: true),
                  const SizedBox(height: 22),
                  Text(
                    medal.name,
                    textAlign: TextAlign.center,
                    style: TellyTypography.displayXL(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontSize: 28, height: 1.15),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    medal.personalLine,
                    key: const Key('unlock_moment_line'),
                    textAlign: TextAlign.center,
                    // w600: thin regular text antialiases below AA contrast (as in TellyEmptyState).
                    style: TellyTypography.bodyLarge(color: TellyColors.textSecondaryOf(context))
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    [
                      medal.rarityLine,
                      if (friends > 0)
                        '$friends ${friends == 1 ? 'person' : 'people'} you follow ${friends == 1 ? 'has' : 'have'} it',
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(flex: 3),
                  TellyPrimaryButton(
                    key: const Key('unlock_moment_pin'),
                    label: pinned ? 'Pinned to profile' : 'Pin to profile',
                    isLoading: _busy,
                    onPressed: pinned ? null : () => _pin(medal),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const Key('unlock_moment_share'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: TellyColors.strokeStrongOf(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => ref.read(storyShareServiceProvider).shareMedals(MedalStory.single(medal)),
                    child: Text('Share card',
                        style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))),
                  ),
                  TextButton(
                    key: const Key('unlock_moment_done'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Done', style: TellyTypography.labelLarge(color: TellyColors.textSecondaryOf(context))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pin(Medal medal) async {
    final snapshot = ref.read(achievementsControllerProvider).valueOrNull;
    if (snapshot != null && snapshot.freePinSlot == null) {
      // All three slots are taken: the medal sheet asks which one to replace.
      await MedalSheet.show(context, medal);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(achievementsControllerProvider.notifier).pin(medal);
    } catch (e) {
      if (!mounted) return;
      final message = e is AchievementsOfflineException ? e.toString() : "Couldn't pin it. Try again.";
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      // Primary text on the tinted chip: the accent itself falls below AA there in light theme.
      child: Text(label,
          style: TellyTypography.labelMedium(color: TellyColors.textPrimaryOf(context))
              .copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

/// Seeded confetti: each piece falls from above the top edge and drifts sideways as
/// [progress] runs 0 → 1. A fixed [progress] draws a still frame (reduced motion).
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final int seed;

  _ConfettiPainter({required this.progress, required this.seed});

  static const _colors = [
    TellyColors.phosphorLime,
    TellyColors.warmAmber,
    TellyColors.electricViolet,
    TellyColors.neonCoral,
    TellyColors.electricCyan,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final paint = Paint();
    for (var i = 0; i < 70; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final start = rnd.nextDouble() * 0.5; // staggered start
      final speed = 0.6 + rnd.nextDouble() * 0.6;
      final drift = (rnd.nextDouble() - 0.5) * 80;
      final spin = rnd.nextDouble() * pi * 2;
      final w = 4 + rnd.nextDouble() * 5;
      final color = _colors[i % _colors.length];
      final t = ((progress - start * 0.4) * speed).clamp(0.0, 1.0);
      final y = -20 + t * (size.height * 0.75 + 20) + rnd.nextDouble() * size.height * 0.25 * t;
      paint.color = color.withValues(alpha: 0.85 * (1 - t * 0.5));
      canvas.save();
      canvas.translate(x0 + drift * t, y);
      canvas.rotate(spin + t * pi * 3);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.45), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress || old.seed != seed;
}
