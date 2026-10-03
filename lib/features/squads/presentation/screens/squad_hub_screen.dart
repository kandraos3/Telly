import 'package:flutter/material.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/squads/domain/squad_canon_aggregator.dart';
import 'package:telly_app/features/squads/domain/squad_models.dart';

/// SCR-17: Squads Hub & Consensus Leaderboard Screen (FE-306).
///
/// Features group consensus rankings aggregated via Borda Count,
/// member roster avatars, dual-canon switching, and debate callout cards.
class SquadHubScreen extends StatefulWidget {
  final Squad squad;
  final List<SquadConsensusItem>? initialConsensus;
  final VoidCallback? onInviteTap;

  const SquadHubScreen({
    super.key,
    required this.squad,
    this.initialConsensus,
    this.onInviteTap,
  });

  @override
  State<SquadHubScreen> createState() => _SquadHubScreenState();
}

class _SquadHubScreenState extends State<SquadHubScreen> {
  String _selectedCanon = 'tv'; // 'movie' or 'tv'
  int _selectedSubTab = 0; // 0: Consensus Canon, 1: Squad Watchlist, 2: Debate

  late List<SquadConsensusItem> _consensusItems;

  @override
  void initState() {
    super.initState();
    _consensusItems = widget.initialConsensus ?? _generateSampleConsensus();
  }

  List<SquadConsensusItem> _generateSampleConsensus() {
    // Generate default sample squad rankings for The Apartment
    final sampleEntries = [
      // Jordan
      const MemberRankEntry(
        userId: 'u_jordan',
        displayName: 'Jordan',
        titleId: 101,
        title: 'Succession',
        releaseYear: 2018,
        mediaType: 'tv',
        rankPosition: 1,
      ),
      const MemberRankEntry(
        userId: 'u_jordan',
        displayName: 'Jordan',
        titleId: 102,
        title: 'Severance',
        releaseYear: 2022,
        mediaType: 'tv',
        rankPosition: 2,
      ),
      const MemberRankEntry(
        userId: 'u_jordan',
        displayName: 'Jordan',
        titleId: 103,
        title: 'The Bear',
        releaseYear: 2022,
        mediaType: 'tv',
        rankPosition: 3,
      ),
      const MemberRankEntry(
        userId: 'u_jordan',
        displayName: 'Jordan',
        titleId: 105,
        title: 'Lost',
        releaseYear: 2004,
        mediaType: 'tv',
        rankPosition: 14,
      ),
      // Maya
      const MemberRankEntry(
        userId: 'u_maya',
        displayName: 'Maya',
        titleId: 102,
        title: 'Severance',
        releaseYear: 2022,
        mediaType: 'tv',
        rankPosition: 1,
      ),
      const MemberRankEntry(
        userId: 'u_maya',
        displayName: 'Maya',
        titleId: 101,
        title: 'Succession',
        releaseYear: 2018,
        mediaType: 'tv',
        rankPosition: 2,
      ),
      const MemberRankEntry(
        userId: 'u_maya',
        displayName: 'Maya',
        titleId: 103,
        title: 'The Bear',
        releaseYear: 2022,
        mediaType: 'tv',
        rankPosition: 4,
      ),
      // Alex
      const MemberRankEntry(
        userId: 'u_alex',
        displayName: 'Alex',
        titleId: 101,
        title: 'Succession',
        releaseYear: 2018,
        mediaType: 'tv',
        rankPosition: 3,
      ),
      const MemberRankEntry(
        userId: 'u_alex',
        displayName: 'Alex',
        titleId: 103,
        title: 'The Bear',
        releaseYear: 2022,
        mediaType: 'tv',
        rankPosition: 1,
      ),
      const MemberRankEntry(
        userId: 'u_alex',
        displayName: 'Alex',
        titleId: 105,
        title: 'Lost',
        releaseYear: 2004,
        mediaType: 'tv',
        rankPosition: 4,
      ),
    ];

    return SquadCanonAggregator.calculateConsensusCanon(
      entries: sampleEntries,
      mediaType: _selectedCanon,
    );
  }

  void _switchCanon(String canon) {
    HapticsService.selectionClick();
    setState(() {
      _selectedCanon = canon;
      _consensusItems = _generateSampleConsensus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final squad = widget.squad;
    final hotDebate = _consensusItems.where((i) => i.isHotDebate).firstOrNull;

    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TellyColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          squad.name.toUpperCase(),
          style: TellyTypography.labelLarge(color: TellyColors.textPrimary).copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {
              HapticsService.lightImpact();
              widget.onInviteTap?.call();
            },
            icon: const Icon(Icons.person_add_outlined, size: 16, color: TellyColors.phosphorLime),
            label: Text(
              'Invite',
              style: TellyTypography.caption(color: TellyColors.phosphorLime).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 1. Members Avatars Row
            _buildMembersRow(squad),
            const SizedBox(height: 16),

            // 2. Sub-tab Navigation: [ Consensus Canon ] [ Squad Watchlist ] [ Debate ]
            _buildSubTabs(),
            const SizedBox(height: 16),

            // 3. Dual-Canon Switcher: [ 🎬 Movie Canon ] [ 📺 Series Canon ]
            _buildCanonSwitcher(),
            const SizedBox(height: 16),

            // 4. Hot Debate Card (if present)
            if (hotDebate != null) ...[
              _buildHotDebateCard(hotDebate),
              const SizedBox(height: 16),
            ],

            // 5. Consensus Header
            Row(
              children: [
                Text(
                  'CONSENSUS LEADERBOARD (BORDA COUNT)',
                  style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_consensusItems.length} Titles',
                  style: TellyTypography.caption(color: TellyColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 6. Ranked Consensus Items
            ..._consensusItems.map((item) => _buildConsensusCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersRow(Squad squad) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'MEMBERS (${squad.members.length})',
                style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Squad consensus weight: 1.0x',
                style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: squad.members.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final member = squad.members[index];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: TellyColors.backgroundCard,
                      child: Text(
                        member.displayName.isNotEmpty ? member.displayName[0] : '?',
                        style: TellyTypography.caption(color: TellyColors.phosphorLime).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      member.displayName,
                      style: TellyTypography.caption(color: TellyColors.textSecondary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabs() {
    final tabs = ['Consensus Canon', 'Squad Watchlist', 'Debates'];

    return Row(
      children: List.generate(tabs.length, (index) {
        final isSelected = _selectedSubTab == index;
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticsService.selectionClick();
              setState(() {
                _selectedSubTab = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? TellyColors.phosphorLime : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                tabs[index],
                style: TellyTypography.caption(
                  color: isSelected ? TellyColors.phosphorLime : TellyColors.textTertiary,
                ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCanonSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _switchCanon('tv'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedCanon == 'tv' ? TellyColors.backgroundCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedCanon == 'tv' ? TellyColors.borderGlass : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '📺 Series Canon',
                  style: TellyTypography.caption(
                    color: _selectedCanon == 'tv' ? TellyColors.phosphorLime : TellyColors.textTertiary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _switchCanon('movie'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedCanon == 'movie' ? TellyColors.backgroundCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedCanon == 'movie' ? TellyColors.borderGlass : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '🎬 Movie Canon',
                  style: TellyTypography.caption(
                    color: _selectedCanon == 'movie' ? TellyColors.phosphorLime : TellyColors.textTertiary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotDebateCard(SquadConsensusItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TellyColors.neonCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.neonCoral.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                "SQUAD'S BIGGEST DEBATE: ${item.title.toUpperCase()}",
                style: TellyTypography.caption(color: TellyColors.neonCoral).copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Divergence: ${(item.lowestRank - item.championRank).abs()} ranks between ${item.championDisplayName} (#${item.championRank}) and ${item.lowestDisplayName} (#${item.lowestRank})',
            style: TellyTypography.caption(color: TellyColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildConsensusCard(SquadConsensusItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.consensusRank <= 3
                  ? TellyColors.phosphorLime.withValues(alpha: 0.15)
                  : TellyColors.backgroundCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.consensusRank <= 3
                    ? TellyColors.phosphorLime
                    : TellyColors.borderGlass,
              ),
            ),
            child: Text(
              '#${item.consensusRank}',
              style: TellyTypography.monoDigits(
                color: item.consensusRank <= 3
                    ? TellyColors.phosphorLime
                    : TellyColors.textSecondary,
              ).copyWith(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Champion/Lowest breakdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: TellyTypography.bodyLarge(color: TellyColors.textPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: TellyColors.backgroundCard,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: TellyColors.borderGlass),
                      ),
                      child: Text(
                        '${item.totalBordaPoints} pts',
                        style: TellyTypography.monoDigits(color: TellyColors.phosphorLime).copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Champion: ${item.championDisplayName} (#${item.championRank}) • Lowest: ${item.lowestDisplayName} (#${item.lowestRank})',
                  style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
