import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../data/tracking_repository.dart';
import '../../domain/tracking_models.dart';

/// What the sheet decided. [place] is null for "starting from the beginning".
class WhereAreYouResult {
  const WhereAreYouResult(this.place);

  final EpisodeRef? place;
}

/// SCR-08 §T.3 / features/11 §4.1: where a series is started from.
class WhereAreYouSheet extends ConsumerStatefulWidget {
  const WhereAreYouSheet({
    super.key,
    required this.titleId,
    required this.seasons,
    this.initialPlace,
  });

  final int titleId;

  /// Seasons ≥ 1, in order.
  final List<SeasonInfo> seasons;

  /// Preselects "I'm partway through" at this episode (a ranked *Up to date* series).
  final EpisodeRef? initialPlace;

  /// Resolves to null when dismissed.
  static Future<WhereAreYouResult?> show(
    BuildContext context, {
    required int titleId,
    required List<SeasonInfo> seasons,
    EpisodeRef? initialPlace,
  }) {
    return TellyFrostedSheet.show<WhereAreYouResult>(
      context: context,
      builder: (_) => WhereAreYouSheet(titleId: titleId, seasons: seasons, initialPlace: initialPlace),
    );
  }

  @override
  ConsumerState<WhereAreYouSheet> createState() => _WhereAreYouSheetState();
}

class _WhereAreYouSheetState extends ConsumerState<WhereAreYouSheet> {
  late bool _partway = widget.initialPlace != null;
  late int _season = widget.initialPlace?.season ?? widget.seasons.first.number;
  late int _episode = widget.initialPlace?.episode ?? 1;
  late FixedExtentScrollController _episodeController = FixedExtentScrollController(initialItem: _episode - 1);
  late final FixedExtentScrollController _seasonController = FixedExtentScrollController(
    initialItem: widget.seasons.indexWhere((s) => s.number == _season).clamp(0, widget.seasons.length - 1),
  );
  final Map<int, List<EpisodeInfo>> _loaded = {};

  @override
  void initState() {
    super.initState();
    if (_partway) _loadSeason(_season);
  }

  @override
  void dispose() {
    _seasonController.dispose();
    _episodeController.dispose();
    super.dispose();
  }

  int get _episodeCount {
    for (final s in widget.seasons) {
      if (s.number == _season) return s.episodeCount < 1 ? 1 : s.episodeCount;
    }
    return 1;
  }

  Future<void> _loadSeason(int season) async {
    if (_loaded.containsKey(season)) return;
    try {
      final episodes = await ref.read(trackingRepositoryProvider).loadSeason(widget.titleId, season);
      if (mounted) setState(() => _loaded[season] = episodes);
    } catch (_) {
      // Offline and never cached: the caption falls back to "Season 2 · Episode 5".
    }
  }

  String get _caption {
    final name = _loaded[_season]?.where((e) => e.episode == _episode).map((e) => e.name).firstOrNull;
    final ref = 'S$_season · E$_episode';
    return name == null || name.isEmpty ? 'Season $_season · Episode $_episode' : "$ref '$name'";
  }

  void _onSeason(int index) {
    final number = widget.seasons[index].number;
    if (number == _season) return;
    setState(() {
      _season = number;
      _episode = _episode.clamp(1, _episodeCount);
      _episodeController.dispose();
      _episodeController = FixedExtentScrollController(initialItem: _episode - 1);
    });
    _loadSeason(number);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('where_are_you_sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where are you?',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _RadioRow(
          key: const Key('where_beginning'),
          label: 'Starting from the beginning',
          selected: !_partway,
          onTap: () => setState(() => _partway = false),
        ),
        _RadioRow(
          key: const Key('where_partway'),
          label: "I'm partway through",
          selected: _partway,
          onTap: () {
            setState(() => _partway = true);
            _loadSeason(_season);
          },
        ),
        if (_partway) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Season', style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'The last episode you watched',
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 120,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    key: const Key('season_wheel'),
                    scrollController: _seasonController,
                    itemExtent: 36,
                    onSelectedItemChanged: _onSeason,
                    children: [
                      for (final s in widget.seasons)
                        Center(child: Text('Season ${s.number}', style: TextStyle(color: TellyColors.textPrimaryOf(context)))),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: CupertinoPicker(
                    key: ValueKey('episode_wheel_$_season'),
                    scrollController: _episodeController,
                    itemExtent: 36,
                    onSelectedItemChanged: (i) => setState(() => _episode = i + 1),
                    children: [
                      for (var e = 1; e <= _episodeCount; e++)
                        Center(child: Text('Episode $e', style: TextStyle(color: TellyColors.textPrimaryOf(context)))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _caption,
            key: const Key('where_caption'),
            style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
          ),
        ],
        const SizedBox(height: 16),
        TellyPrimaryButton(
          key: const Key('start_tracking_button'),
          label: 'Start tracking',
          onPressed: () => Navigator.of(context).pop(
            WhereAreYouResult(_partway ? EpisodeRef(_season, _episode) : null),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lime = TellyColors.primaryAccentOf(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? lime : TellyColors.textTertiaryOf(context), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
