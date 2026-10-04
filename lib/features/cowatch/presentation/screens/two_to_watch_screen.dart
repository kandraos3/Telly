import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/network/supabase_providers.dart';
import 'package:telly_app/core/services/streaming_deep_link_factory.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/cowatch/data/co_watch_repository.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';
import 'package:telly_app/features/cowatch/presentation/widgets/quick_swipe_deck_modal.dart';

/// SCR-16: "Two-to-Watch" Co-Watching Decider Hub.
/// Conforms to `FE-404`, `FE-405` and
/// `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §16.
class TwoToWatchScreen extends ConsumerStatefulWidget {
  final String friendId;
  final String friendHandle;
  final String friendDisplayName;
  final int matchPercentage;
  final int? movieMatchPercentage;
  final int? seriesMatchPercentage;
  final List<CoWatchCandidate>? initialCandidates;

  const TwoToWatchScreen({
    super.key,
    required this.friendId,
    required this.friendHandle,
    required this.friendDisplayName,
    this.matchPercentage = 88,
    this.movieMatchPercentage = 92,
    this.seriesMatchPercentage = 84,
    this.initialCandidates,
  });

  @override
  ConsumerState<TwoToWatchScreen> createState() => _TwoToWatchScreenState();
}

class _TwoToWatchScreenState extends ConsumerState<TwoToWatchScreen> {
  CoWatchFormat _selectedFormat = CoWatchFormat.movieNight;
  RuntimeBudget? _selectedRuntimeBudget;
  late final Set<String> _userAProviders;
  late final Set<String> _userBProviders;
  late Set<String> _activeSharedProviders;
  final Set<String> _selectedVibes = {};
  List<ScoredRecommendation> _recommendations = [];
  bool _hasSearched = false;

  late List<CoWatchCandidate> _allCandidates;

  static const List<CoWatchCandidate> _defaultFallbackCandidates = [
    CoWatchCandidate(
      showId: 101,
      title: 'Parasite',
      mediaType: 'movie',
      runtimeMinutes: 132,
      network: 'Neon',
      availableProviders: ['max'],
      vibeTags: ['thriller', 'festival_darling'],
      inWatchlistA: true,
      inWatchlistB: true,
      communityScore: 9.7,
      overview: 'Greed and class discrimination threaten the newly formed symbiotic relationship.',
    ),
    CoWatchCandidate(
      showId: 102,
      title: 'Past Lives',
      mediaType: 'movie',
      runtimeMinutes: 106,
      network: 'A24',
      availableProviders: ['netflix'],
      vibeTags: ['festival_darling'],
      inWatchlistA: true,
      inWatchlistB: false,
      ratingB: 9.4,
      communityScore: 9.2,
      overview: 'Nora and Hae Sung, two deeply connected childhood friends, are reunited.',
    ),
    CoWatchCandidate(
      showId: 103,
      title: 'Run Lola Run',
      mediaType: 'movie',
      runtimeMinutes: 81,
      network: 'Sony',
      availableProviders: ['max'],
      vibeTags: ['thriller'],
      communityScore: 8.4,
      overview: 'After a botched money delivery, Lola has 20 minutes to find 100,000 marks.',
    ),
    CoWatchCandidate(
      showId: 201,
      title: 'Chernobyl',
      mediaType: 'tv',
      network: 'HBO',
      availableProviders: ['max'],
      vibeTags: ['thriller', 'miniseries'],
      inWatchlistA: true,
      inWatchlistB: true,
      communityScore: 9.8,
      overview: 'In April 1986, an explosion at the Chernobyl nuclear power plant occurs.',
    ),
    CoWatchCandidate(
      showId: 202,
      title: 'Severance',
      mediaType: 'tv',
      network: 'Apple TV+',
      availableProviders: ['apple_tv_plus'],
      vibeTags: ['sci_fi', 'thriller'],
      ratingA: 9.5,
      ratingB: 9.5,
      communityScore: 9.4,
      overview: 'Mark leads a team whose memories have been surgically divided.',
    ),
    CoWatchCandidate(
      showId: 203,
      title: 'The Bear',
      mediaType: 'tv',
      network: 'FX',
      availableProviders: ['hulu'],
      vibeTags: ['comedy', 'prestige'],
      communityScore: 9.1,
      overview: 'A young chef from the fine dining world comes home to Chicago.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Default shared streaming providers: Netflix, Max, Apple TV+
    _userAProviders = {'netflix', 'max', 'apple_tv_plus', 'prime_video'};
    _userBProviders = {'netflix', 'max', 'apple_tv_plus', 'hulu'};
    _activeSharedProviders = TwoToWatchEngine.computeSharedProviders(
      providersA: _userAProviders,
      providersB: _userBProviders,
    );

    _allCandidates = widget.initialCandidates ?? _defaultFallbackCandidates;
    _calculateRecommendations();

    if (widget.initialCandidates == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRemoteCandidates();
      });
    }
  }

  Future<void> _loadRemoteCandidates() async {
    try {
      final repo = ref.read(coWatchRepositoryProvider);
      final remote = await repo.fetchCandidates(
        partnerId: widget.friendId,
        mediaType: _selectedFormat.mediaType,
      );
      if (mounted && remote.isNotEmpty) {
        setState(() {
          _allCandidates = remote;
          _calculateRecommendations();
        });
      }
    } catch (_) {
      // Offline fallback already present in _allCandidates
    }
  }

  void _calculateRecommendations() {
    final scored = TwoToWatchEngine.scoreCandidates(
      candidates: _allCandidates,
      activeSharedProviders: _activeSharedProviders,
      format: _selectedFormat,
      runtimeBudget: _selectedRuntimeBudget,
      selectedVibes: _selectedVibes.toList(),
      tasteMatchPercentage: widget.matchPercentage,
    );

    setState(() {
      _recommendations = scored;
      _hasSearched = true;
    });
  }

  void _selectFormat(CoWatchFormat format) {
    if (_selectedFormat == format) return;
    setState(() {
      _selectedFormat = format;
      _calculateRecommendations();
    });
    if (widget.initialCandidates == null) {
      _loadRemoteCandidates();
    }
  }

  void _openQuickSwipeMode() {
    final formatCandidates = _allCandidates.where((c) => c.mediaType == _selectedFormat.mediaType).toList();
    String? currentUserId;
    try {
      currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    } catch (_) {}
    final myId = currentUserId ?? 'me';
    final sorted = [myId, widget.friendId]..sort();
    final sessionId = 'cowatch-${sorted.join('-')}';

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => QuickSwipeDeckModal(
        candidates: formatCandidates,
        friendHandle: '@${widget.friendHandle}',
        friendId: widget.friendId,
        sessionId: sessionId,
        sharedProviders: _activeSharedProviders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: TellyColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'TWO-TO-WATCH',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: TellyColors.phosphorLime),
            tooltip: '15s Quick Swipe Mode',
            onPressed: _openQuickSwipeMode,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Who's on the Couch Header
            _buildCouchHeader(),
            const SizedBox(height: 20),

            // 2. Format Selection (Movie Night vs Series)
            _buildFormatSelector(),
            const SizedBox(height: 16),

            // 3. Runtime Budget Filters (Active for Movie Night)
            if (_selectedFormat == CoWatchFormat.movieNight) ...[
              _buildRuntimeBudgetSelector(),
              const SizedBox(height: 16),
            ],

            // 4. Shared Streaming Services
            _buildStreamingFilter(),
            const SizedBox(height: 16),

            // 5. What's the Vibe? Chips
            _buildVibeSelector(),
            const SizedBox(height: 24),

            // 6. Action Button: Find What to Watch
            TellyPrimaryButton(
              label: '🎲 FIND WHAT TO WATCH TONIGHT',
              onPressed: _calculateRecommendations,
            ),
            const SizedBox(height: 12),

            // Secondary Quick Swipe Trigger
            Center(
              child: TextButton.icon(
                onPressed: _openQuickSwipeMode,
                icon: const Icon(Icons.swipe, size: 16, color: TellyColors.phosphorLime),
                label: Text(
                  'Can\'t agree? Try 15-Second Quick Swipe Mode',
                  style: TellyTypography.caption(color: TellyColors.phosphorLime).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 7. Results Section
            if (_hasSearched) _buildRecommendationsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCouchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHO\'S ON THE COUCH?',
            style: TellyTypography.labelSmall(
              color: TellyColors.textTertiary,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: TellyColors.backgroundCard,
                child: Text('Y', style: TextStyle(color: TellyColors.textPrimary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              const Text('You', style: TextStyle(color: TellyColors.textPrimary, fontWeight: FontWeight.w700)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('+', style: TextStyle(color: TellyColors.textPrimary, fontSize: 16)),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: TellyColors.backgroundCard,
                child: Text(
                  widget.friendDisplayName.isNotEmpty ? widget.friendDisplayName[0] : 'F',
                  style: const TextStyle(color: TellyColors.phosphorLime, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.friendDisplayName,
                style: const TextStyle(color: TellyColors.textPrimary, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TellyNeonBadge(
                label: '${widget.matchPercentage}% MATCH',
                variant: TellyBadgeVariant.tasteMatch,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FORMAT SELECTION',
          style: TellyTypography.labelSmall(
            color: TellyColors.textTertiary,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildFormatPill(
                format: CoWatchFormat.movieNight,
                icon: '🎬',
                title: 'Movie Night',
                subtitle: 'Single sitting',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormatPill(
                format: CoWatchFormat.series,
                icon: '📺',
                title: 'TV Series',
                subtitle: 'Multi-episode run',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatPill({
    required CoWatchFormat format,
    required String icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedFormat == format;
    return InkWell(
      onTap: () => _selectFormat(format),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? TellyColors.phosphorLime.withValues(alpha: 0.12) : TellyColors.backgroundSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? TellyColors.phosphorLime : TellyColors.borderGlass,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TellyTypography.labelLarge(
                    color: isSelected ? TellyColors.phosphorLime : TellyColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuntimeBudgetSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RUNTIME BUDGET',
          style: TellyTypography.labelSmall(
            color: TellyColors.textTertiary,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: RuntimeBudget.values.map((budget) {
            final isSelected = _selectedRuntimeBudget == budget;
            return ChoiceChip(
              label: Text(budget.label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedRuntimeBudget = selected ? budget : null;
                  _calculateRecommendations();
                });
              },
              backgroundColor: TellyColors.backgroundSurface,
              selectedColor: TellyColors.warmAmber.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected ? TellyColors.warmAmber : TellyColors.borderGlass,
              ),
              labelStyle: TextStyle(
                color: isSelected ? TellyColors.warmAmber : TellyColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStreamingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SHARED STREAMING SERVICES',
              style: TellyTypography.labelSmall(
                color: TellyColors.textTertiary,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
            ),
            Text(
              'Auto-detected overlap',
              style: TellyTypography.caption(color: TellyColors.phosphorLime).copyWith(fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['netflix', 'max', 'apple_tv_plus'].map((service) {
            final isSelected = _activeSharedProviders.contains(service);
            return FilterChip(
              label: Text(service.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _activeSharedProviders.add(service);
                  } else {
                    _activeSharedProviders.remove(service);
                  }
                  _calculateRecommendations();
                });
              },
              backgroundColor: TellyColors.backgroundSurface,
              selectedColor: TellyColors.phosphorLime.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected ? TellyColors.phosphorLime : TellyColors.borderGlass,
              ),
              labelStyle: TextStyle(
                color: isSelected ? TellyColors.phosphorLime : TellyColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVibeSelector() {
    const vibes = [
      ('thriller', 'Thriller / Mystery'),
      ('sci_fi', 'Mind-Bending Sci-Fi'),
      ('comedy', 'Laugh-Out-Loud'),
      ('festival_darling', 'Oscar / Festival Darling'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT\'S THE VIBE?',
          style: TellyTypography.labelSmall(
            color: TellyColors.textTertiary,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: vibes.map((vibe) {
            final isSelected = _selectedVibes.contains(vibe.$1);
            return FilterChip(
              label: Text(vibe.$2),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedVibes.add(vibe.$1);
                  } else {
                    _selectedVibes.remove(vibe.$1);
                  }
                  _calculateRecommendations();
                });
              },
              backgroundColor: TellyColors.backgroundSurface,
              selectedColor: TellyColors.electricViolet.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected ? TellyColors.electricViolet : TellyColors.borderGlass,
              ),
              labelStyle: TextStyle(
                color: isSelected ? TellyColors.electricViolet : TellyColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: TellyColors.phosphorLime,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TOP PICKS FOR TONIGHT (${_recommendations.length})',
              style: TellyTypography.labelSmall(
                color: TellyColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recommendations.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: TellyColors.backgroundSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'No titles found matching current filters.\nTry selecting more streaming services or widening runtime.',
                textAlign: TextAlign.center,
                style: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
              ),
            ),
          )
        else
          ..._recommendations.take(3).map((rec) => _buildRecommendationCard(rec)),
      ],
    );
  }

  Widget _buildRecommendationCard(ScoredRecommendation rec) {
    final candidate = rec.candidate;
    final primaryProvider = rec.matchedProviders.isNotEmpty ? rec.matchedProviders.first : 'max';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(Routes.title(candidate.mediaType, candidate.showId)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.title,
                          style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${candidate.network} • ${candidate.runtimeMinutes != null ? '${candidate.runtimeMinutes}m • ' : ''}★ ${candidate.communityScore.toStringAsFixed(1)}',
                          style: TellyTypography.caption(color: TellyColors.warmAmber),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TellyColors.phosphorLime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${rec.score.toStringAsFixed(0)} PTS',
                      style: TellyTypography.caption(
                        color: TellyColors.phosphorLime,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rec.matchReason,
            style: TellyTypography.caption(color: TellyColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TellyNeonBadge(
                label: 'ON ${primaryProvider.toUpperCase()}',
                variant: TellyBadgeVariant.winner,
              ),
              ElevatedButton.icon(
                onPressed: () {
                  StreamingDeepLinkFactory.launchPlayback(
                    providerId: primaryProvider,
                    externalShowId: '${candidate.showId}',
                    showSlug: candidate.title.toLowerCase().replaceAll(' ', '-'),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TellyColors.phosphorLime,
                  foregroundColor: TellyColors.backgroundCanvasOled,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text(
                  'Watch on ${primaryProvider.toUpperCase()}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
