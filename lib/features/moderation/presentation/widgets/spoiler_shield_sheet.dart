library spoiler_shield_sheet;

import 'package:flutter/material.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/features/moderation/domain/moderation_models.dart';

/// Modal bottom sheet allowing users to proactively mute titles from feed to shield against spoilers.
/// Conforms to `FE-508` and `docs/adjacent_systems/05_TRUST_SAFETY_MODERATION_AND_ADMIN.md` §2.1.
class SpoilerShieldSheet extends StatefulWidget {
  final List<MutedTitle> initialMutedTitles;
  final ValueChanged<List<MutedTitle>>? onMutedListChanged;

  const SpoilerShieldSheet({
    super.key,
    this.initialMutedTitles = const [],
    this.onMutedListChanged,
  });

  static Future<List<MutedTitle>?> show({
    required BuildContext context,
    List<MutedTitle> initialMutedTitles = const [],
  }) {
    return showModalBottomSheet<List<MutedTitle>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpoilerShieldSheet(
        initialMutedTitles: initialMutedTitles,
      ),
    );
  }

  @override
  State<SpoilerShieldSheet> createState() => _SpoilerShieldSheetState();
}

class _SpoilerShieldSheetState extends State<SpoilerShieldSheet> {
  late List<MutedTitle> _mutedTitles;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _trendingShows = [
    {'id': 94997, 'title': 'House of the Dragon', 'mediaType': 'tv'},
    {'id': 110492, 'title': 'Severance', 'mediaType': 'tv'},
    {'id': 111803, 'title': 'The White Lotus', 'mediaType': 'tv'},
    {'id': 85937, 'title': 'Demon Slayer', 'mediaType': 'tv'},
    {'id': 872585, 'title': 'Oppenheimer', 'mediaType': 'movie'},
  ];

  @override
  void initState() {
    super.initState();
    _mutedTitles = widget.initialMutedTitles.isNotEmpty
        ? List.from(widget.initialMutedTitles)
        : [
            MutedTitle(
              tmdbId: 94997,
              title: 'House of the Dragon',
              mediaType: 'tv',
              mutedAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addMutedTitle(int id, String title, String mediaType) {
    if (_mutedTitles.any((m) => m.tmdbId == id)) return;

    setState(() {
      _mutedTitles.add(
        MutedTitle(
          tmdbId: id,
          title: title,
          mediaType: mediaType,
          mutedAt: DateTime.now(),
        ),
      );
    });

    widget.onMutedListChanged?.call(_mutedTitles);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Muted "$title" — all posts shielded until unmuted.'),
          backgroundColor: TellyColors.cardOf(context),
        ),
      );
  }

  void _removeMutedTitle(int id) {
    setState(() {
      _mutedTitles.removeWhere((m) => m.tmdbId == id);
    });

    widget.onMutedListChanged?.call(_mutedTitles);
  }

  void _addCustomTitle() {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;

    _addMutedTitle(
      DateTime.now().millisecondsSinceEpoch % 100000,
      text,
      'tv',
    );
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: TellyColors.borderGlassOf(context)),
          left: BorderSide(color: TellyColors.borderGlassOf(context)),
          right: BorderSide(color: TellyColors.borderGlassOf(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TellyColors.strokeSubtleOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🛡️ SPOILER SHIELD',
                style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: TellyColors.textSecondaryOf(context), size: 20),
                onPressed: () => Navigator.of(context).pop(_mutedTitles),
              ),
            ],
          ),
          Text(
            'Proactively mute titles to hide all reviews, reactions, and feed cards until you finish watching.',
            style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
          ),
          const SizedBox(height: 16),

          // Search / Add Title Field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: TellyColors.textPrimaryOf(context), fontSize: 13),
                  onSubmitted: (_) => _addCustomTitle(),
                  decoration: InputDecoration(
                    hintText: 'Mute a show (e.g. Severance S2)...',
                    hintStyle: TextStyle(color: TellyColors.textTertiaryOf(context), fontSize: 12),
                    filled: true,
                    fillColor: TellyColors.cardOf(context),
                    prefixIcon: Icon(Icons.search, color: TellyColors.textTertiaryOf(context), size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: TellyColors.phosphorLime),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: TellyColors.phosphorLime),
                icon: const Icon(Icons.add, color: Colors.black, size: 20),
                onPressed: _addCustomTitle,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Trending Mute Suggestions
          Text(
            'POPULAR TITLES TO SHIELD',
            style: TellyTypography.labelSmall(color: TellyColors.textSecondaryOf(context)).copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _trendingShows.map((show) {
                final isMuted = _mutedTitles.any((m) => m.tmdbId == show['id']);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      isMuted ? Icons.check : Icons.shield_outlined,
                      size: 14,
                      color: isMuted ? TellyColors.phosphorLime : TellyColors.textSecondaryOf(context),
                    ),
                    label: Text(show['title'] as String),
                    backgroundColor: isMuted
                        ? TellyColors.phosphorLime.withValues(alpha: 0.15)
                        : TellyColors.cardOf(context),
                    side: BorderSide(
                      color: isMuted ? TellyColors.phosphorLime : TellyColors.borderGlassOf(context),
                    ),
                    labelStyle: TextStyle(
                      color: isMuted ? TellyColors.phosphorLime : TellyColors.textPrimaryOf(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    onPressed: () {
                      if (isMuted) {
                        _removeMutedTitle(show['id'] as int);
                      } else {
                        _addMutedTitle(
                          show['id'] as int,
                          show['title'] as String,
                          show['mediaType'] as String,
                        );
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Active Muted Titles List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURRENTLY SHIELDED (${_mutedTitles.length})',
                style: TellyTypography.labelSmall(color: TellyColors.textSecondaryOf(context)).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              if (_mutedTitles.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _mutedTitles.clear();
                    });
                    widget.onMutedListChanged?.call(_mutedTitles);
                  },
                  child: const Text(
                    'Unmute All',
                    style: TextStyle(color: TellyColors.neonCoral, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          Expanded(
            child: _mutedTitles.isEmpty
                ? Center(
                    child: Text(
                      'No titles currently shielded.\nAll feed posts and spoilers are visible.',
                      textAlign: TextAlign.center,
                      style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                    ),
                  )
                : ListView.separated(
                    itemCount: _mutedTitles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final title = _mutedTitles[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: TellyColors.cardOf(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TellyColors.borderGlassOf(context)),
                        ),
                        child: Row(
                          children: [
                            TellyNeonBadge(
                              label: title.mediaType.toUpperCase(),
                              variant: TellyBadgeVariant.neutral,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title.title,
                                style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: TellyColors.textTertiaryOf(context), size: 18),
                              onPressed: () => _removeMutedTitle(title.tmdbId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

