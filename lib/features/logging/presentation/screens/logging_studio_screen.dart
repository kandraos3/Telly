import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../profile/presentation/controllers/graveyard_controller.dart';
import '../../../profile/presentation/widgets/log_dropped_show_sheet.dart';
import '../../../ranking/domain/sentiment_bracket.dart';
import '../../domain/title_search_result.dart';
import '../../domain/watch_status.dart';
import '../controllers/logging_session_controller.dart';
import '../widgets/star_rating_selector.dart';

/// `SCR-09` The Logging Studio (FE-603, redesigned in FE-LOG-02).
///
/// Search (150 ms debounce) → selected title → watch status → half-star rating (sets the
/// sentiment bracket) → broadcast opt-out →
/// `BEGIN PAIRWISE DUELS` pushes `SCR-10` with the draft held by [loggingSessionProvider].
class LoggingStudioScreen extends ConsumerStatefulWidget {
  /// Pre-selects a title, e.g. "Reset Duels for This Show" (features/02 §7.2).
  final TitleSearchResult? initialTitle;

  const LoggingStudioScreen({super.key, this.initialTitle});

  @override
  ConsumerState<LoggingStudioScreen> createState() => _LoggingStudioScreenState();
}

class _LoggingStudioScreenState extends ConsumerState<LoggingStudioScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTitle;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(loggingSessionProvider.notifier).selectTitle(initial);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _close() => context.canPop() ? context.pop() : context.go(Routes.home);

  Future<void> _onStatus(WatchStatus status) async {
    final session = ref.read(loggingSessionProvider.notifier);
    final title = ref.read(loggingSessionProvider).title;
    if (title == null) return;
    if (status != WatchStatus.dropped) {
      session.setStatus(status);
      return;
    }
    // Dropped shows are not ranked: they go to the TV Graveyard (features/03 §2).
    final details = await LogDroppedShowSheet.show(
      context: context,
      titleId: title.id,
      title: title.title,
      releaseYear: int.tryParse(title.releaseYear) ?? 0,
    );
    if (details == null || !mounted) return;
    try {
      await ref
          .read(graveyardControllerProvider.notifier)
          .drop(titleId: title.id, mediaType: title.mediaType, details: details);
      if (mounted) context.go(Routes.graveyard);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't add it to your Graveyard. Try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(loggingSessionProvider);
    final title = draft.title;

    return Scaffold(
      appBar: TellySubpageAppBar(
        nav: TellyNavKind.close,
        navKey: const Key('logging_cancel'),
        title: 'Log a show',
        onNav: _close,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: title == null
                  ? _SearchPane(controller: _searchController, draft: draft)
                  : _DraftPane(draft: draft, title: title, onStatus: _onStatus),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: TellyPrimaryButton(
                  key: const Key('begin_duels_button'),
                  label: 'BEGIN PAIRWISE DUELS (3-4 BATTLES)  →',
                  onPressed: draft.canBeginDuels ? () => context.push(Routes.duel) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchPane extends ConsumerWidget {
  final TextEditingController controller;
  final LoggingDraft draft;
  const _SearchPane({required this.controller, required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(loggingSessionProvider.notifier);
    final search = draft.search;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            key: const Key('logging_search_field'),
            controller: controller,
            autofocus: true,
            onChanged: session.updateQuery,
            style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context)),
            decoration: InputDecoration(
              hintText: 'Search movies & shows',
              hintStyle: TellyTypography.bodyLarge(color: TellyColors.textTertiaryOf(context)),
              prefixIcon: Icon(Icons.search, color: TellyColors.textTertiaryOf(context)),
              filled: true,
              fillColor: TellyColors.surfaceOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: TellyColors.strokeOf(context)),
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (search) {
            null => const SizedBox.shrink(),
            AsyncLoading() => Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
            AsyncError() => const _Message('Search failed. Check your connection and try again.'),
            AsyncData(:final value) when value.results.isEmpty => _Message('No titles found for “${draft.query}”.'),
            AsyncData(:final value) => ListView(
                children: [
                  if (value.fromLocalCache)
                    Padding(
                      key: const Key('logging_offline_notice'),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Text('Offline: showing saved titles',
                          style: TellyTypography.caption(color: TellyColors.warmAmberOf(context))),
                    ),
                  for (final r in value.results)
                    ListTile(
                      key: Key('search_result_${r.mediaType}_${r.id}'),
                      onTap: () => session.selectTitle(r),
                      title: Text(r.title, style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
                      subtitle: Text(
                        [if (r.releaseYear.isNotEmpty) r.releaseYear, _kind(r)].join(' · '),
                        style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                      ),
                    ),
                ],
              ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  static String _kind(TitleSearchResult r) => r.isMovie ? 'Movie' : (r.isAnime ? 'Anime' : 'Series');
}

class _Message extends StatelessWidget {
  final String text;
  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center, style: TellyTypography.bodyMedium()),
      );
}

class _DraftPane extends ConsumerWidget {
  final LoggingDraft draft;
  final TitleSearchResult title;
  final ValueChanged<WatchStatus> onStatus;
  const _DraftPane({required this.draft, required this.title, required this.onStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(loggingSessionProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Selected: ${title.title.toUpperCase()}${title.releaseYear.isEmpty ? '' : ' (${title.releaseYear})'}',
                key: const Key('logging_selected_title'),
                style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)),
              ),
            ),
            TextButton(
              key: const Key('logging_change_title'),
              onPressed: session.clearTitle,
              child: Text('Change', style: TellyTypography.labelMedium(color: TellyColors.primaryAccentOf(context))),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionHeader('1. HOW MUCH DID YOU WATCH?'),
        for (final status in WatchStatus.optionsFor(title.mediaType))
          _StatusOption(
            status: status,
            selected: draft.status == status,
            onTap: () => onStatus(status),
            trailing: status == WatchStatus.season && draft.status == WatchStatus.season
                ? _SeasonStepper(
                    season: draft.seasonNumber,
                    onChanged: session.setSeasonNumber,
                  )
                : null,
          ),
        const SizedBox(height: 32),
        const _SectionHeader('2. YOUR RATING'),
        Text('Half stars count. Your rating sets where the duels start.',
            style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Center(
          child: StarRatingSelector(
            key: const Key('logging_star_rating'),
            value: draft.starRating,
            onChanged: session.setStarRating,
          ),
        ),
        const SizedBox(height: 8),
        _RatingCaption(stars: draft.starRating, bracket: draft.bracket),
        const SizedBox(height: 32),
        const _SectionHeader('3. SHARING'),
        _BroadcastToggle(value: draft.broadcast, onChanged: session.setBroadcast),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800)),
      );
}

class _StatusOption extends StatelessWidget {
  final WatchStatus status;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  const _StatusOption({required this.status, required this.selected, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        key: Key('status_${status.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? TellyColors.primaryAccentOf(context) : TellyColors.textTertiaryOf(context),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(status.label, style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context)))),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonStepper extends StatelessWidget {
  final int season;
  final ValueChanged<int> onChanged;
  const _SeasonStepper({required this.season, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('season_decrement'),
          onPressed: season > 1 ? () => onChanged(season - 1) : null,
          icon: const Icon(Icons.remove, size: 18),
          color: TellyColors.textPrimaryOf(context),
        ),
        Text('Season $season', key: const Key('season_label'), style: TellyTypography.labelMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w700)),
        IconButton(
          key: const Key('season_increment'),
          onPressed: () => onChanged(season + 1),
          icon: const Icon(Icons.add, size: 18),
          color: TellyColors.textPrimaryOf(context),
        ),
      ],
    );
  }
}

class _RatingCaption extends StatelessWidget {
  final double? stars;
  final SentimentBracket? bracket;
  const _RatingCaption({required this.stars, required this.bracket});

  @override
  Widget build(BuildContext context) {
    final stars = this.stars;
    final bracket = this.bracket;
    if (stars == null || bracket == null) {
      return Text('Tap a star to rate', textAlign: TextAlign.center, style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w600));
    }
    final value = stars == stars.roundToDouble() ? stars.toStringAsFixed(0) : stars.toStringAsFixed(1);
    return Column(
      key: const Key('logging_rating_caption'),
      children: [
        Text('$value / 5  ·  ${bracket.studioTitle}',
            textAlign: TextAlign.center, style: TellyTypography.titleMedium(color: TellyColors.warmAmberOf(context))),
        const SizedBox(height: 4),
        Text('“${bracket.studioTagline}”', textAlign: TextAlign.center, style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _BroadcastToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _BroadcastToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: const Key('logging_broadcast_checkbox'),
      value: value,
      onChanged: (v) => onChanged(v ?? true),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: TellyColors.primaryAccentOf(context),
      checkColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
      side: BorderSide(color: TellyColors.strokeStrongOf(context), width: 1.5),
      title: Text('Broadcast to Feed', style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))),
      subtitle: Text(
        value ? 'Friends will see this log in their feed.' : 'Private: ranked in your canon, hidden from the feed.',
        style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
