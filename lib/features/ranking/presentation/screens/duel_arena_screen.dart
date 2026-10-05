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
  /// The duel loop's state and actions (a logging session, or the onboarding tournament).
  final ProviderListenable<DuelState> state;
  final ProviderListenable<DuelActions> actions;
  final VoidCallback? onCancel;
  final ValueChanged<DuelComplete>? onDuelComplete;

  /// Replaces `DUEL X OF Y` (e.g. `Movie Duel 2 of 3 • Calibrating your Movie Canon`).
  final String Function(DuelActive active)? progressLabel;
  final String tieLabel;

  /// `SCR-10` for a logging session (FE-604).
  DuelArenaScreen({
    super.key,
    required DuelRequest request,
    this.onCancel,
    this.onDuelComplete,
  })  : state = duelControllerProvider(request),
        actions = duelControllerProvider(request).notifier,
        progressLabel = null,
        tieLabel = "Can't Compare / Equal";

  /// The arena driven by another duel loop, e.g. the `SCR-04` onboarding tournament (FE-606).
  const DuelArenaScreen.custom({
    super.key,
    required this.state,
    required this.actions,
    this.onCancel,
    this.onDuelComplete,
    this.progressLabel,
    this.tieLabel = "Can't Compare / Equal",
  });

  @override
  ConsumerState<DuelArenaScreen> createState() => _DuelArenaScreenState();
}

class _DuelArenaScreenState extends ConsumerState<DuelArenaScreen> with SingleTickerProviderStateMixin {
  static const _swipeThreshold = 100.0;

  int? _selectedWinnerId;

  /// Only the dragged card moves: A (upper) may only rise, B (lower) may only fall, and the
  /// VS badge stays anchored (FE-GESTURE-01). Null when no card is being dragged.
  _DuelSlot? _draggingSlot;
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

  void _onDragUpdate(_DuelSlot slot, DragUpdateDetails details) {
    if (_selectedWinnerId != null) return;
    _springController.stop();
    setState(() {
      if (_draggingSlot != slot) _dragOffsetY = 0;
      _draggingSlot = slot;
      final next = _dragOffsetY + details.delta.dy;
      // A card only travels toward its own pick direction.
      _dragOffsetY =
          slot == _DuelSlot.upper ? next.clamp(double.negativeInfinity, 0.0) : next.clamp(0.0, double.infinity);
    });
  }

  void _onDragEnd(_DuelSlot slot, DuelActive active) {
    if (_selectedWinnerId != null || _draggingSlot != slot) return;

    if (_dragOffsetY.abs() > _swipeThreshold) {
      // Swiped the upper card UP picks the candidate; the lower card DOWN picks the opponent.
      _handleSelection(slot == _DuelSlot.upper ? active.candidate.showId : active.currentOpponent.showId);
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
            if (_springController.isCompleted) _draggingSlot = null;
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
      _draggingSlot = null;
    });

    // Trigger sensory tactile feedback
    await ref.read(hapticsServiceProvider).duelWinner();

    // Brief delay to allow 220ms winner scale & loser fade animations to render
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    await ref.read(widget.actions).voteWinner(winnerId);

    if (mounted) {
      setState(() {
        _selectedWinnerId = null;
      });
    }
  }

  Future<void> _handleSkipOrTie() async {
    if (_selectedWinnerId != null) return;
    await ref.read(hapticsServiceProvider).duelSelectCandidate();
    await ref.read(widget.actions).skipOrTie();
  }

  double _swipeProgress(_DuelSlot slot) =>
      _draggingSlot == slot ? (_dragOffsetY.abs() / _swipeThreshold).clamp(0.0, 1.0) : 0.0;

  double _highlightFor(_DuelSlot slot) => _selectedWinnerId == null ? _swipeProgress(slot) : 0.0;

  /// Translates and tilts only the dragged card; the idle card dims as the swipe commits.
  Widget _draggableCard({required _DuelSlot slot, required DuelActive active, required Widget child}) {
    final dragging = _draggingSlot == slot;
    final other = slot == _DuelSlot.upper ? _DuelSlot.lower : _DuelSlot.upper;
    final dim = _selectedWinnerId == null ? _swipeProgress(other) : 0.0;
    return GestureDetector(
      onVerticalDragUpdate: (d) => _onDragUpdate(slot, d),
      onVerticalDragEnd: (_) => _onDragEnd(slot, active),
      child: Opacity(
        opacity: 1 - 0.45 * dim,
        child: Transform.translate(
          offset: Offset(0, dragging ? _dragOffsetY : 0),
          child: Transform.rotate(
            angle: dragging ? _dragOffsetY / 4000 : 0,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.state;
    final duelState = ref.watch(provider);

    // Listen for completion
    ref.listen<DuelState>(provider, (previous, next) {
      if (next is DuelComplete) {
        widget.onDuelComplete?.call(next);
      }
    });

    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
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
                  style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context)),
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
                tooltip: 'Close duel',
                icon: Icon(Icons.close, color: TellyColors.textSecondaryOf(context)),
                onPressed: widget.onCancel ?? () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  widget.progressLabel?.call(activeState) ?? 'DUEL $step OF $totalSteps',
                  key: const Key('duel_step_counter_text'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.titleMedium(
                    color: TellyColors.textPrimaryOf(context),
                  ).copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: widget.progressLabel == null ? 1.5 : 0,
                  ),
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
              backgroundColor: TellyColors.cardOf(context),
              valueColor: const AlwaysStoppedAnimation<Color>(TellyColors.phosphorLime),
            ),
          ),

          const SizedBox(height: 16),

          // Arena Prompt
          Text(
            'WHICH DID YOU PREFER OVERALL?',
            style: TellyTypography.bodyMedium(
              color: TellyColors.textSecondaryOf(context),
            ).copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          // 2. THE DUEL CARDS — each card owns its swipe; the VS badge never moves.
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Candidate Card A (Upper Card)
                Expanded(
                  child: _draggableCard(
                    slot: _DuelSlot.upper,
                    active: activeState,
                    child: DuelArenaCard(
                      key: const Key('candidate_card_a'),
                      showId: candidate.showId,
                      title: candidate.title,
                      subtitle: candidate.mediaType == 'movie' ? 'Movie Canon Candidate' : 'Series Canon Candidate',
                      posterPath: candidate.posterPath,
                      actionPrompt: 'TAP OR SWIPE UP TO PICK',
                      isWinner: candidateWon,
                      isLoser: hasSelection && !candidateWon,
                      dragHighlight: _highlightFor(_DuelSlot.upper),
                      onTap: () => _handleSelection(candidate.showId),
                    ),
                  ),
                ),

                // Central Glowing VS Badge
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    key: const Key('duel_vs_badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: TellyColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: TellyColors.borderGlassOf(context)),
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
                  child: _draggableCard(
                    slot: _DuelSlot.lower,
                    active: activeState,
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
                      dragHighlight: _highlightFor(_DuelSlot.lower),
                      onTap: () => _handleSelection(opponent.showId),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. BOTTOM ACTION: CAN'T COMPARE / EQUAL
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  color: TellyColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TellyColors.borderGlassOf(context)),
                ),
                child: TextButton.icon(
                  key: const Key('cant_compare_button'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: hasSelection ? null : _handleSkipOrTie,
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: TellyColors.textSecondaryOf(context),
                    size: 18,
                  ),
                  label: Text(
                    widget.tieLabel,
                    style: TellyTypography.bodyLarge(
                      color: TellyColors.textSecondaryOf(context),
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

enum _DuelSlot { upper, lower }
