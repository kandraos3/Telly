import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../domain/canon_type.dart';
import '../../domain/score_curve_calculator.dart';
import '../../data/ranking_repository.dart';
import '../widgets/canon_tier_style.dart';
import '../widgets/reveal_leaderboard_snippet.dart';

/// SCR-12 Celebration Slot Reveal Modal with Number Ticker.
/// Conforms to:
/// - `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §12 (SCR-12)
/// - `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §4 (Slot Reveal)
class SlotRevealModal extends ConsumerStatefulWidget {
  final int showId;
  final String title;
  final String mediaType; // 'movie' or 'tv'
  final String? posterPath;
  final int rankPosition;
  final int totalInCanon;
  final double targetScore;
  final List<String> beatingTitles;
  final List<String> justBehindTitles;

  /// Rows around the new entry; when present they replace the beating/just-behind text.
  final List<RevealLeaderboardEntry> leaderboard;
  final VoidCallback onViewInCanon;
  final VoidCallback? onShareStory;
  final VoidCallback? onClose;

  const SlotRevealModal({
    super.key,
    required this.showId,
    required this.title,
    required this.mediaType,
    this.posterPath,
    required this.rankPosition,
    required this.totalInCanon,
    required this.targetScore,
    this.beatingTitles = const [],
    this.justBehindTitles = const [],
    this.leaderboard = const [],
    required this.onViewInCanon,
    this.onShareStory,
    this.onClose,
  });

  @override
  ConsumerState<SlotRevealModal> createState() => _SlotRevealModalState();

  /// Static helper to display [SlotRevealModal] as a full-screen or modal dialog.
  static Future<void> show({
    required BuildContext context,
    required int showId,
    required String title,
    required String mediaType,
    String? posterPath,
    required int rankPosition,
    required int totalInCanon,
    required double targetScore,
    List<String> beatingTitles = const [],
    List<String> justBehindTitles = const [],
    List<RevealLeaderboardEntry> leaderboard = const [],
    required VoidCallback onViewInCanon,
    VoidCallback? onShareStory,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).brightness == Brightness.light
          ? Colors.black54
          : TellyColors.backgroundPrimary.withValues(alpha: 0.92),
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: TellyColors.canvasOf(context),
        child: SlotRevealModal(
          showId: showId,
          title: title,
          mediaType: mediaType,
          posterPath: posterPath,
          rankPosition: rankPosition,
          totalInCanon: totalInCanon,
          targetScore: targetScore,
          beatingTitles: beatingTitles,
          justBehindTitles: justBehindTitles,
          leaderboard: leaderboard,
          onViewInCanon: () {
            Navigator.of(ctx).pop();
            onViewInCanon();
          },
          onShareStory: () {
            onShareStory?.call();
          },
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }
}

class _SlotRevealModalState extends ConsumerState<SlotRevealModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scoreAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  bool get _isMovie => CanonType.fromMediaType(widget.mediaType) == CanonType.movie;
  CanonTier get _tier => CanonTier.fromScore(widget.targetScore);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: widget.targetScore,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    ));

    _controller.forward();

    // Trigger sequential celebratory haptic pulses
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hapticsServiceProvider).scoreReveal(
            pulses: 4,
            interval: const Duration(milliseconds: 120),
          );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canonLabel = _isMovie ? 'Movie Canon' : 'Series Canon';
    final mediaUnit = _isMovie ? 'Titles' : 'Shows';

    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // 1. TOP HEADER WITH CLOSE BUTTON
              // Close sits on the left, like every pushed screen (FE-HEADER-02).
              Align(
                alignment: Alignment.centerLeft,
                child: TellyNavButton(
                  key: const Key('slot_reveal_close_button'),
                  kind: TellyNavKind.close,
                  onPressed: widget.onClose,
                ),
              ),

              // 2. SCROLLABLE REVEAL CONTENT
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Celebration Header
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              '🎉 CANON UPDATED!',
                              key: const Key('canon_updated_headline'),
                              style: TellyTypography.titleLarge(color: TellyColors.textPrimaryOf(context)).copyWith(
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your personal leaderboard has recalibrated',
                              style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Animated Title Reveal Card
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            key: const Key('slot_reveal_card'),
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: TellyColors.surfaceOf(context),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: TellyColors.phosphorLime.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: TellyColors.phosphorLime.withValues(alpha: 0.15),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Poster Thumbnail (or Fallback Icon)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 80,
                                    height: 120,
                                    child: PosterImage(
                                      posterPath: widget.posterPath,
                                      fallback: _buildPosterFallback(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Title Name
                                Text(
                                  widget.title.toUpperCase(),
                                  key: const Key('slot_reveal_title_text'),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TellyTypography.displayXL(color: TellyColors.textPrimaryOf(context)),
                                ),

                                const SizedBox(height: 10),

                                // Rank Position in Canon
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: TellyColors.cardOf(context),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: TellyColors.borderGlassOf(context)),
                                  ),
                                  child: Text(
                                    'Rank: #${widget.rankPosition} of ${widget.totalInCanon} $mediaUnit in your $canonLabel',
                                    key: const Key('slot_reveal_rank_text'),
                                    style: TellyTypography.labelSmall(color: TellyColors.textSecondaryOf(context)).copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Number Ticker Score
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _scoreAnimation,
                                      builder: (context, _) {
                                        return Text(
                                          _scoreAnimation.value.toStringAsFixed(2),
                                          key: const Key('slot_reveal_score_ticker'),
                                          style: TellyTypography.scoreHero(
                                            color: TellyColors.phosphorLime,
                                          ).copyWith(fontSize: 44),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '/ 10.0',
                                      style: TellyTypography.titleMedium(
                                        color: TellyColors.textTertiaryOf(context),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Tier Badge
                                _buildTierBadge(_tier),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Ranking Context: leaderboard snippet, else Beating / Just behind
                      if (widget.leaderboard.isNotEmpty) ...[
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: RevealLeaderboardSnippet(
                            key: const Key('reveal_leaderboard_snippet'),
                            entries: widget.leaderboard,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else if (widget.justBehindTitles.isNotEmpty || widget.beatingTitles.isNotEmpty) ...[
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: TellyColors.cardOf(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: TellyColors.borderGlassOf(context)),
                            ),
                            child: Column(
                              children: [
                                if (widget.justBehindTitles.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.arrow_upward, size: 14, color: TellyColors.textTertiaryOf(context)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Just behind: ${widget.justBehindTitles.join(", ")}',
                                          key: const Key('just_behind_text'),
                                          style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (widget.justBehindTitles.isNotEmpty &&
                                    widget.beatingTitles.isNotEmpty) ...[
                                  Divider(color: TellyColors.borderGlassOf(context), height: 12),
                                ],
                                if (widget.beatingTitles.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.arrow_downward, size: 14, color: TellyColors.phosphorLime),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Beating: ${widget.beatingTitles.join(", ")}',
                                          key: const Key('beating_text'),
                                          style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. BOTTOM ACTIONS (Pinned at bottom)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Primary Action: View in My Canon
                    TellyPrimaryButton(
                      key: const Key('view_in_canon_button'),
                      label: 'VIEW IN MY CANON PROFILE',
                      onPressed: widget.onViewInCanon,
                    ),

                    const SizedBox(height: 10),

                    // Secondary Action: Share to Story
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const Key('share_story_button'),
                        icon: Icon(Icons.camera_alt_outlined, size: 18, color: TellyColors.textPrimaryOf(context)),
                        label: Text(
                          'Share to Instagram Story',
                          style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: TellyColors.strokeSubtleOf(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: widget.onShareStory,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

  }

  Widget _buildPosterFallback(BuildContext context) {
    return Container(
      width: 72,
      height: 100,
      decoration: BoxDecoration(
        color: TellyColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.strokeSubtleOf(context)),
      ),
      child: Center(
        child: Icon(
          _isMovie ? Icons.movie_outlined : Icons.tv_outlined,
          color: TellyColors.textTertiaryOf(context),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildTierBadge(CanonTier tier) {
    return CanonTierBadge(key: const Key('slot_reveal_tier_badge'), tier: tier);
  }
}
