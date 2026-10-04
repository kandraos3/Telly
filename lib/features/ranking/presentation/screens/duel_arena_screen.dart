import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../controllers/duel_controller.dart';
import '../widgets/duel_arena_card.dart';

/// Screen implementing SCR-10 Binary Duel Arena.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §10,
/// `docs/design_system/02_COMPONENT_LIBRARY_AND_PATTERNS.md` §4, and
/// `docs/design_system/04_USER_INTERACTION_FLOWS_AND_GESTURES.md` §1.
class DuelArenaScreen extends ConsumerStatefulWidget {
  /// The logging session being placed (FE-604); keys the [duelControllerProvider] family.
  final DuelRequest request;
  final VoidCallback? onCancel;
  final ValueChanged<DuelComplete>? onDuelComplete;

  const DuelArenaScreen({
    super.key,
    required this.request,
    this.onCancel,
    this.onDuelComplete,
  });

  @override
  ConsumerState<DuelArenaScreen> createState() => _DuelArenaScreenState();
}

class _DuelArenaScreenState extends ConsumerState<DuelArenaScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedWinnerId;
  double _dragOffsetY = 0.0;
  late AnimationController _springController;
  late Animation<double> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _springAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_selectedWinnerId != null) return;
    setState(() {
      _dragOffsetY += details.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails details, DuelActive active) {
    if (_selectedWinnerId != null) return;

    const threshold = 100.0;
    if (_dragOffsetY < -threshold) {
      // Swiped UP -> Select Candidate A (Upper Card)
      _handleSelection(active.candidate.showId);
    } else if (_dragOffsetY > threshold) {
      // Swiped DOWN -> Select Candidate B (Lower Card)
      _handleSelection(active.currentOpponent.showId);
    } else {
      // Drag < threshold -> Spring back to 0
      _springAnimation = Tween<double>(
        begin: _dragOffsetY,
        end: 0.0,
      ).animate(
        CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
      )..addListener(() {
          setState(() {
            _dragOffsetY = _springAnimation.value;
          });
        });
      _springController.forward(from: 0.0);
    }
  }

  Future<void> _handleSelection(int winnerId) async {
    if (_selectedWinnerId != null) return;

    setState(() {
      _selectedWinnerId = winnerId;
      _dragOffsetY = 0.0;
    });

    // Trigger sensory tactile feedback
    await ref.read(hapticsServiceProvider).duelWinner();

    // Brief delay to allow 220ms winner scale & loser fade animations to render
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    await ref.read(duelControllerProvider(widget.request).notifier).voteWinner(winnerId);

    if (mounted) {
      setState(() {
        _selectedWinnerId = null;
      });
    }
  }

  Future<void> _handleSkipOrTie() async {
    if (_selectedWinnerId != null) return;
    await ref.read(hapticsServiceProvider).duelSelectCandidate();
    await ref.read(duelControllerProvider(widget.request).notifier).skipOrTie();
  }

  @override
  Widget build(BuildContext context) {
    final provider = duelControllerProvider(widget.request);
    final duelState = ref.watch(provider);

    // Listen for completion
    ref.listen<DuelState>(provider, (previous, next) {
      if (next is DuelComplete) {
        widget.onDuelComplete?.call(next);
      }
    });

    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      body: SafeArea(
        child: switch (duelState) {
          DuelInitial() => const Center(
              child: CircularProgressIndicator(color: TellyColors.phosphorLime),
            ),
          DuelResolving() => const Center(
              child: CircularProgressIndicator(color: TellyColors.phosphorLime),
            ),
          DuelComplete() => const Center(
              child: Icon(Icons.check_circle, color: TellyColors.phosphorLime, size: 64),
            ),
          DuelFailed() => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Couldn't save this ranking. Please try again.",
                  key: const Key('duel_failed_text'),
                  textAlign: TextAlign.center,
                  style: TellyTypography.bodyLarge(),
                ),
              ),
            ),
          DuelActive(:final candidate, :final currentOpponent, :final step, :final totalEstimatedSteps) =>
            _buildArenaContent(
              activeState: duelState,
              candidate: candidate,
              opponent: currentOpponent,
              step: step,
              totalSteps: totalEstimatedSteps,
            ),
        },
      ),
    );
  }

  Widget _buildArenaContent({
    required DuelActive activeState,
    required dynamic candidate,
    required dynamic opponent,
    required int step,
    required int totalSteps,
  }) {
    final candidateWon = _selectedWinnerId == candidate.showId;
    final opponentWon = _selectedWinnerId == opponent.showId;
    final hasSelection = _selectedWinnerId != null;

    final progressRatio = totalSteps > 0 ? (step / totalSteps).clamp(0.0, 1.0) : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // 1. TOP STATUS BAR (DUEL X OF Y, CANCEL, PROGRESS)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const Key('duel_arena_close_button'),
                icon: const Icon(Icons.close, color: TellyColors.textSecondary),
                onPressed: widget.onCancel ?? () => Navigator.of(context).maybePop(),
              ),
              Text(
                'DUEL $step OF $totalSteps',
                key: const Key('duel_step_counter_text'),
                style: TellyTypography.titleMedium(
                  color: TellyColors.textPrimary,
                ).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 48), // Balance close button width
            ],
          ),

          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 4,
              backgroundColor: TellyColors.backgroundCard,
              valueColor: const AlwaysStoppedAnimation<Color>(TellyColors.phosphorLime),
            ),
          ),

          const SizedBox(height: 16),

          // Arena Prompt
          Text(
            'WHICH DID YOU PREFER OVERALL?',
            style: TellyTypography.bodyMedium(
              color: TellyColors.textSecondary,
            ).copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          // 2. THE DUEL CARDS WITH GESTURE DETECTOR
          Expanded(
            child: GestureDetector(
              onVerticalDragUpdate: _onPanUpdate,
              onVerticalDragEnd: (details) => _onPanEnd(details, activeState),
              child: Transform.translate(
                offset: Offset(0, _dragOffsetY),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Candidate Card A (Upper Card)
                    Expanded(
                      child: DuelArenaCard(
                        key: const Key('candidate_card_a'),
                        showId: candidate.showId,
                        title: candidate.title,
                        subtitle: candidate.mediaType == 'movie'
                            ? 'Movie Canon Candidate'
                            : 'Series Canon Candidate',
                        posterPath: candidate.posterPath,
                        actionPrompt: 'TAP OR SWIPE UP TO PICK',
                        isWinner: candidateWon,
                        isLoser: hasSelection && !candidateWon,
                        onTap: () => _handleSelection(candidate.showId),
                      ),
                    ),

                    // Central Glowing VS Badge
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        key: const Key('duel_vs_badge'),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: TellyColors.backgroundSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: TellyColors.borderGlass),
                          boxShadow: [
                            BoxShadow(
                              color: TellyColors.neonCoral.withValues(alpha: 0.25),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Text(
                          '━  VS  ━',
                          style: TellyTypography.titleMedium(
                            color: TellyColors.neonCoral,
                          ).copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),

                    // Candidate Card B (Lower Card - Opponent)
                    Expanded(
                      child: DuelArenaCard(
                        key: const Key('candidate_card_b'),
                        showId: opponent.showId,
                        title: opponent.title,
                        subtitle: opponent.rankPosition > 0
                            ? 'Currently your #${opponent.rankPosition} (${opponent.calculatedScore.toStringAsFixed(2)})'
                            : 'Comparison Title',
                        posterPath: opponent.posterPath,
                        actionPrompt: 'TAP OR SWIPE DOWN TO PICK',
                        isWinner: opponentWon,
                        isLoser: hasSelection && !opponentWon,
                        onTap: () => _handleSelection(opponent.showId),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. BOTTOM ACTION: CAN'T COMPARE / EQUAL
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: TellyColors.backgroundSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TellyColors.borderGlass),
                ),
                child: TextButton.icon(
                  key: const Key('cant_compare_button'),
                  onPressed: hasSelection ? null : _handleSkipOrTie,
                  icon: const Icon(
                    Icons.shuffle_rounded,
                    color: TellyColors.textSecondary,
                    size: 18,
                  ),
                  label: Text(
                    "Can't Compare / Equal",
                    style: TellyTypography.bodyLarge(
                      color: TellyColors.textSecondary,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
