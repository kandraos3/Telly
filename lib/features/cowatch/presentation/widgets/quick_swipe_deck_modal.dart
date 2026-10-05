import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telly_app/core/services/streaming_deep_link_factory.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/features/cowatch/data/co_watch_repository.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';

/// 15-Second "Rapid Swipe" Duel Mode Modal.
/// Conforms to `FE-406`, `FE-610` and `docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md` §3.2.
class QuickSwipeDeckModal extends ConsumerStatefulWidget {
  final List<CoWatchCandidate> candidates;
  final String friendHandle;
  final Set<String> sharedProviders;
  final VoidCallback? onDismiss;
  final String? sessionId;
  final String? friendId;
  final CoWatchSessionClient? sessionClient;

  const QuickSwipeDeckModal({
    super.key,
    required this.candidates,
    required this.friendHandle,
    required this.sharedProviders,
    this.onDismiss,
    this.sessionId,
    this.friendId,
    this.sessionClient,
  });

  @override
  ConsumerState<QuickSwipeDeckModal> createState() => _QuickSwipeDeckModalState();
}

class _QuickSwipeDeckModalState extends ConsumerState<QuickSwipeDeckModal> {
  final CardSwiperController _swiperController = CardSwiperController();
  int _secondsLeft = 15;
  Timer? _countdownTimer;
  CoWatchCandidate? _matchedTitle;
  bool _isMatched = false;
  bool _isPartnerConnected = false;

  late final CoWatchSessionClient _sessionClient;
  StreamSubscription<int>? _matchSubscription;
  StreamSubscription<Set<String>>? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _initSessionClient();
    _startTimer();
  }

  void _initSessionClient() {
    if (widget.sessionClient != null) {
      _sessionClient = widget.sessionClient!;
    } else {
      final sessId = widget.sessionId ??
          'cowatch-${widget.friendHandle.replaceAll('@', '')}';
      try {
        _sessionClient = ref.read(coWatchRepositoryProvider).createSessionClient(
              sessionId: sessId,
            );
      } catch (_) {
        _sessionClient = FakeCoWatchSessionClient(
          sessionId: sessId,
          currentUserId: 'me',
        );
      }
    }

    _matchSubscription = _sessionClient.onMutualMatch.listen((titleId) {
      if (!mounted || _isMatched) return;
      try {
        final match = widget.candidates.firstWhere((c) => c.showId == titleId);
        _triggerMatch(match);
      } catch (_) {}
    });

    _presenceSubscription = _sessionClient.onPresence.listen((users) {
      if (!mounted) return;
      setState(() {
        _isPartnerConnected = users.length > 1 ||
            (widget.friendId != null && users.contains(widget.friendId));
      });
    });

    _sessionClient.join();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        if (!_isMatched && mounted) {
          // Time expired without mutual match
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Time expired! Returning to recommendation list.'),
              backgroundColor: TellyColors.backgroundCard,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    _presenceSubscription?.cancel();
    if (widget.sessionClient == null) {
      _sessionClient.dispose();
    }
    _countdownTimer?.cancel();
    _swiperController.dispose();
    super.dispose();
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (previousIndex < widget.candidates.length) {
      final swipedCandidate = widget.candidates[previousIndex];
      _sessionClient.sendSwipe(
        titleId: swipedCandidate.showId,
        direction: direction == CardSwiperDirection.right
            ? SwipeDirection.right
            : SwipeDirection.left,
      );
    }
    return true;
  }

  void _triggerMatch(CoWatchCandidate candidate) {
    _countdownTimer?.cancel();
    setState(() {
      _matchedTitle = candidate;
      _isMatched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: TellyColors.backgroundSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: TellyColors.borderGlass),
        ),
        padding: const EdgeInsets.all(20),
        child: _isMatched ? _buildMatchView() : _buildSwiperView(),
      ),
    );
  }

  Widget _buildSwiperView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with 15s Countdown Timer & Presence
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUICK SWIPE DUEL',
                  style: TellyTypography.labelSmall(
                    color: TellyColors.phosphorLime,
                  ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                Row(
                  children: [
                    Text(
                      'With ${widget.friendHandle}',
                      style: TellyTypography.caption(color: TellyColors.textTertiary),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _isPartnerConnected
                            ? TellyColors.phosphorLime
                            : TellyColors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isPartnerConnected ? 'Connected' : 'Waiting',
                      style: TellyTypography.caption(
                        color: _isPartnerConnected
                            ? TellyColors.phosphorLime
                            : TellyColors.textTertiary,
                      ).copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _secondsLeft <= 5 ? TellyColors.neonCoral.withValues(alpha: 0.2) : TellyColors.backgroundCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _secondsLeft <= 5 ? TellyColors.neonCoral : TellyColors.strokeSubtle,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: _secondsLeft <= 5 ? TellyColors.neonCoral : TellyColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_secondsLeft}s',
                    style: TellyTypography.labelMedium(
                      color: _secondsLeft <= 5 ? TellyColors.neonCoral : TellyColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Swiper Deck
        SizedBox(
          height: 380,
          child: widget.candidates.isEmpty
              ? Center(
                  child: Text(
                    'No candidates left to swipe!',
                    style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
                  ),
                )
              : CardSwiper(
                  controller: _swiperController,
                  cardsCount: widget.candidates.length,
                  onSwipe: _onSwipe,
                  numberOfCardsDisplayed: widget.candidates.length > 3 ? 3 : widget.candidates.length,
                  backCardOffset: const Offset(0, 20),
                  cardBuilder: (context, index, percentX, percentY) {
                    final item = widget.candidates[index];
                    return _buildSwipeCard(item);
                  },
                ),
        ),
        const SizedBox(height: 16),

        // Bottom Controls: Pass (Left) vs Match (Right)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton.small(
              heroTag: 'pass_btn',
              backgroundColor: TellyColors.backgroundCard,
              foregroundColor: TellyColors.neonCoral,
              onPressed: () => _swiperController.swipe(CardSwiperDirection.left),
              child: const Icon(Icons.close, size: 20),
            ),
            const SizedBox(width: 32),
            FloatingActionButton(
              heroTag: 'watch_btn',
              backgroundColor: TellyColors.phosphorLime,
              foregroundColor: TellyColors.backgroundCanvasOled,
              onPressed: () => _swiperController.swipe(CardSwiperDirection.right),
              child: const Icon(Icons.check, size: 28),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwipeCard(CoWatchCandidate item) {
    return Container(
      decoration: BoxDecoration(
        color: TellyColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TellyColors.borderGlass),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: TellyColors.backgroundCardAlt,
                // FE-COWATCH-01: the contender's real TMDB poster, the icon only as fallback.
                child: PosterImage(
                  key: Key('quick_swipe_poster_${item.showId}'),
                  posterPath: item.posterPath,
                  fallback: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                          size: 64,
                          color: TellyColors.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.network.toUpperCase(),
                          style: TellyTypography.caption(color: TellyColors.warmAmber).copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.headlineSmall(color: TellyColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.runtimeMinutes != null)
                        Text(
                          '${item.runtimeMinutes} min • ',
                          style: TellyTypography.caption(color: TellyColors.textSecondary),
                        ),
                      Text(
                        '★ ${item.communityScore.toStringAsFixed(1)} Community',
                        style: TellyTypography.caption(color: TellyColors.warmAmber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: item.availableProviders
                        .map<Widget>(
                          (p) => TellyNeonBadge(
                            label: StreamingPlatform.labelFor(p).toUpperCase(),
                            variant: TellyBadgeVariant.tasteMatch,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchView() {
    final matched = _matchedTitle!;
    // Prefer a service we both have; never invent one the title isn't on.
    final primaryProvider = matched.availableProviders.where(widget.sharedProviders.contains).firstOrNull ??
        matched.availableProviders.firstOrNull;
    final details = [
      if (primaryProvider != null) 'Available on ${StreamingPlatform.labelFor(primaryProvider)}',
      if (matched.runtimeMinutes != null) '${matched.runtimeMinutes}m',
    ].join(' • ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.celebration, color: TellyColors.phosphorLime, size: 48),
        const SizedBox(height: 12),
        Text(
          'IT\'S A MATCH! 🍿',
          style: TellyTypography.titleLarge(
            color: TellyColors.phosphorLime,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'You and ${widget.friendHandle} both swiped right!',
          style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TellyColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TellyColors.phosphorLime.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                matched.title,
                style: TellyTypography.titleLarge(color: TellyColors.textPrimary).copyWith(fontWeight: FontWeight.w800),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(details, style: TellyTypography.caption(color: TellyColors.textSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (primaryProvider != null)
          ElevatedButton(
            onPressed: () {
              StreamingDeepLinkFactory.launchPlayback(
                providerId: primaryProvider,
                externalShowId: '${matched.showId}',
                showSlug: matched.title.toLowerCase().replaceAll(' ', '-'),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TellyColors.phosphorLime,
              foregroundColor: TellyColors.backgroundCanvasOled,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              '▶ Watch on ${StreamingPlatform.labelFor(primaryProvider)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: TellyTypography.labelMedium(color: TellyColors.textTertiary),
          ),
        ),
      ],
    );
  }
}
