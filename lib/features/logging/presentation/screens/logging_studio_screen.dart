import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../profile/presentation/widgets/log_dropped_show_sheet.dart';
import '../../../ranking/domain/sentiment_bracket.dart';
import '../../domain/title_search_result.dart';
import '../../domain/watch_status.dart';
import '../controllers/logging_session_controller.dart';

/// `SCR-09` The Logging Studio & Sentiment Bracket Selector (FE-603).
///
/// Search (150 ms debounce) → selected title → watch status → sentiment bracket →
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

  void _close() => context.canPop() ? context.pop() : context.go(Routes.feed);

  Future<void> _onStatus(WatchStatus status) async {
    final session = ref.read(loggingSessionProvider.notifier);
    final title = ref.read(loggingSessionProvider).title;
    if (title == null) return;
    if (status != WatchStatus.dropped) {
      session.setStatus(status);
      return;
    }
    // Dropped shows are not ranked: they go to the TV Graveyard (features/03 §2).
    final dropped = await LogDroppedShowSheet.show(
      context: context,
      titleId: title.id,
      title: title.title,
      releaseYear: int.tryParse(title.releaseYear) ?? 0,
    );
    if (dropped != null && mounted) context.go(Routes.graveyard, extra: dropped);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(loggingSessionProvider);
    final title = draft.title;

    return Scaffold(
      backgroundColor: TellyColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onCancel: _close),
            const Divider(height: 1, color: TellyColors.strokeSubtle),
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

class _Header extends StatelessWidget {
  final VoidCallback onCancel;
  const _Header({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('logging_cancel'),
              onPressed: onCancel,
              child: Text('✕ Cancel', style: TellyTypography.labelMedium(color: TellyColors.textSecondary)),
            ),
          ),
          Text('LOG A SHOW', style: TellyTypography.labelLarge()),
        ],
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
            style: TellyTypography.bodyLarge(color: TellyColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search movies & shows',
              hintStyle: TellyTypography.bodyLarge(color: TellyColors.textTertiary),
              prefixIcon: const Icon(Icons.search, color: TellyColors.textTertiary),
              filled: true,
              fillColor: TellyColors.backgroundSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: TellyColors.strokeSubtle),
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (search) {
            null => const SizedBox.shrink(),
            AsyncLoading() => const Center(child: CircularProgressIndicator(color: TellyColors.phosphorLime)),
            AsyncError() => const _Message('Search failed. Check your connection and try again.'),
            AsyncData(:final value) when value.results.isEmpty => _Message('No titles found for “${draft.query}”.'),
            AsyncData(:final value) => ListView(
                children: [
                  if (value.fromLocalCache)
                    Padding(
                      key: const Key('logging_offline_notice'),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Text('Offline: showing saved titles',
                          style: TellyTypography.caption(color: TellyColors.warmAmber)),
                    ),
                  for (final r in value.results)
                    ListTile(
                      key: Key('search_result_${r.mediaType}_${r.id}'),
                      onTap: () => session.selectTitle(r),
                      title: Text(r.title, style: TellyTypography.titleMedium()),
                      subtitle: Text(
                        [if (r.releaseYear.isNotEmpty) r.releaseYear, _kind(r)].join(' · '),
                        style: TellyTypography.caption(),
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
                style: TellyTypography.titleMedium(),
              ),
            ),
            TextButton(
              key: const Key('logging_change_title'),
              onPressed: session.clearTitle,
              child: Text('Change', style: TellyTypography.labelMedium(color: TellyColors.phosphorLime)),
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
        const SizedBox(height: 24),
        const _SectionHeader('2. INITIAL SENTIMENT BRACKET'),
        Text('Where does this roughly belong in your taste canon?', style: TellyTypography.bodyMedium()),
        const SizedBox(height: 12),
        for (final bracket in SentimentBracketExtension.studioBrackets)
          _BracketCard(
            bracket: bracket,
            selected: draft.bracket == bracket,
            onTap: () => session.setBracket(bracket),
          ),
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
        child: Text(text, style: TellyTypography.labelLarge(color: TellyColors.textSecondary)),
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
                color: selected ? TellyColors.phosphorLime : TellyColors.textTertiary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(status.label, style: TellyTypography.bodyLarge())),
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
          color: TellyColors.textSecondary,
        ),
        Text('Season $season', key: const Key('season_label'), style: TellyTypography.labelMedium()),
        IconButton(
          key: const Key('season_increment'),
          onPressed: () => onChanged(season + 1),
          icon: const Icon(Icons.add, size: 18),
          color: TellyColors.textSecondary,
        ),
      ],
    );
  }
}

class _BracketCard extends StatelessWidget {
  final SentimentBracket bracket;
  final bool selected;
  final VoidCallback onTap;
  const _BracketCard({required this.bracket, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          key: Key('bracket_${bracket.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? TellyColors.phosphorLime.withValues(alpha: 0.08) : TellyColors.backgroundSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? TellyColors.phosphorLime : TellyColors.strokeSubtle,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: TellyColors.phosphorLime.withValues(alpha: 0.25), blurRadius: 12)]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bracket.studioTitle, style: TellyTypography.titleMedium()),
                      const SizedBox(height: 4),
                      Text('“${bracket.studioTagline}”', style: TellyTypography.caption()),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, key: Key('bracket_selected_check'), color: TellyColors.phosphorLime),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
