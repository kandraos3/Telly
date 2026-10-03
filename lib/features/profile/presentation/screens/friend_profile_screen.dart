import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/cowatch/domain/spearman_taste_match_calculator.dart';
import 'package:telly_app/features/cowatch/presentation/screens/two_to_watch_screen.dart';
import 'package:telly_app/features/profile/presentation/widgets/taste_breakdown_section.dart';
import 'package:telly_app/features/profile/presentation/widgets/taste_match_dial.dart';

/// SCR-15: Friend Profile & Taste Comparison View.
/// Conforms to `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §15
/// and `docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md` §2.
class FriendProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String handle;
  final String displayName;
  final String? avatarUrl;
  final String location;
  final int initialMatchPercentage;
  final int mutualTitleCount;
  final int? movieMatchPercentage;
  final int? seriesMatchPercentage;
  final List<RankedTitleComparison>? initialAgreements;
  final List<RankedTitleComparison>? initialClashes;
  final List<UnwatchedGem>? initialGems;

  const FriendProfileScreen({
    super.key,
    required this.userId,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
    this.location = 'Brooklyn, NY',
    this.initialMatchPercentage = 88,
    this.mutualTitleCount = 34,
    this.movieMatchPercentage = 92,
    this.seriesMatchPercentage = 84,
    this.initialAgreements,
    this.initialClashes,
    this.initialGems,
  });

  @override
  ConsumerState<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  bool _isFollowing = true;
  late final List<RankedTitleComparison> _agreements;
  late final List<RankedTitleComparison> _clashes;
  late final List<UnwatchedGem> _gems;

  @override
  void initState() {
    super.initState();
    _agreements = widget.initialAgreements ??
        [
          const RankedTitleComparison(
            showId: 101,
            title: 'Succession',
            rankA: 1,
            rankB: 2,
            scoreA: 10.0,
            scoreB: 9.8,
            reviewB: 'The sharpest dialogue on television.',
          ),
          const RankedTitleComparison(
            showId: 102,
            title: 'Severance',
            rankA: 3,
            rankB: 3,
            scoreA: 9.4,
            scoreB: 9.4,
          ),
          const RankedTitleComparison(
            showId: 103,
            title: 'The Bear',
            rankA: 5,
            rankB: 6,
            scoreA: 9.1,
            scoreB: 8.9,
          ),
        ];

    _clashes = widget.initialClashes ??
        [
          const RankedTitleComparison(
            showId: 104,
            title: 'Game of Thrones',
            rankA: 8,
            rankB: 64,
            scoreA: 9.3,
            scoreB: 5.1,
            reviewB: 'Season 8 ruined the entire franchise for me.',
          ),
        ];

    _gems = widget.initialGems ??
        [
          const UnwatchedGem(
            showId: 201,
            title: 'Station Eleven',
            friendRank: 4,
            friendScore: 9.3,
            mediaType: 'Series',
            network: 'HBO / Max',
          ),
          const UnwatchedGem(
            showId: 202,
            title: 'Whiplash',
            friendRank: 5,
            friendScore: 9.2,
            mediaType: 'Movie',
            network: 'Sony Pictures',
          ),
        ];
  }

  void _onToggleFollow() {
    setState(() {
      _isFollowing = !_isFollowing;
    });
  }

  void _onQueueGem(UnwatchedGem gem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${gem.title}" to your Queue!'),
        backgroundColor: TellyColors.backgroundCard,
      ),
    );
  }

  void _openTwoToWatch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => TwoToWatchScreen(
          friendId: widget.userId,
          friendHandle: widget.handle,
          friendDisplayName: widget.displayName,
          matchPercentage: widget.initialMatchPercentage,
          movieMatchPercentage: widget.movieMatchPercentage,
          seriesMatchPercentage: widget.seriesMatchPercentage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final affinityTier = TasteAffinityTier.fromPercentage(widget.initialMatchPercentage);

    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TellyColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '@${widget.handle}',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: OutlinedButton(
                onPressed: _onToggleFollow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isFollowing ? TellyColors.textSecondary : TellyColors.phosphorLime,
                  side: BorderSide(
                    color: _isFollowing ? TellyColors.strokeSubtle : TellyColors.phosphorLime,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  _isFollowing ? 'Following' : '+ Follow',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // User identity header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: TellyColors.backgroundCard,
                  child: Text(
                    widget.displayName.isNotEmpty ? widget.displayName[0] : '?',
                    style: const TextStyle(fontSize: 22, color: TellyColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayName,
                        style: TellyTypography.headlineSmall(color: TellyColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.location,
                        style: TellyTypography.caption(color: TellyColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Radial Taste Match Dial
            TasteMatchDial(
              matchPercentage: widget.initialMatchPercentage,
              mutualTitleCount: widget.mutualTitleCount,
              affinityTier: affinityTier,
            ),
            const SizedBox(height: 24),

            // Primary Action: Two-to-Watch
            TellyPrimaryButton(
              label: '🍿 Two-to-Watch with @${widget.handle}',
              onPressed: _openTwoToWatch,
            ),
            const SizedBox(height: 20),

            // Dual Taste Match Breakdown (FE-402)
            DualTasteMatchBreakdown(
              movieMatchPercentage: widget.movieMatchPercentage,
              seriesMatchPercentage: widget.seriesMatchPercentage,
            ),
            const SizedBox(height: 24),

            // Agreements, Clashes, and Unwatched Gems (FE-403)
            TasteComparisonsSection(
              friendHandle: '@${widget.handle}',
              agreements: _agreements,
              clashes: _clashes,
              unwatchedGems: _gems,
              onAddGemToQueue: _onQueueGem,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
