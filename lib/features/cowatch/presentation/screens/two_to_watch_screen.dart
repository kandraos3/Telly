import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/streaming_deep_link_factory.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/cowatch/data/co_watch_repository.dart';
import 'package:telly_app/features/cowatch/domain/two_to_watch_engine.dart';
import 'package:telly_app/features/cowatch/presentation/controllers/two_to_watch_controller.dart';
import 'package:telly_app/features/cowatch/presentation/widgets/quick_swipe_deck_modal.dart';
import 'package:telly_app/features/queue/domain/streaming_models.dart';

/// SCR-16: "Two-to-Watch" Co-Watching Decider.
///
/// FE-COWATCH-01 streamlines the hub into three steps (Who's watching → The mood →
/// Tonight's picks) backed by [TwoToWatchController]: real follows, the real shared
/// streaming overlap, real taste match and the real `get_co_watch_candidates` pool.
/// Conforms to `docs/features/05_TASTE_MATCH_AND_CO_WATCH_DECIDER.md` §3.
class TwoToWatchScreen extends ConsumerWidget {
  final String? friendId;
  final String? friendHandle;
  final String? friendDisplayName;
  final int? preselectedTitleId;
  final String? preselectedMediaType;

  const TwoToWatchScreen({
    super.key,
    this.friendId,
    this.friendHandle,
    this.friendDisplayName,
    this.preselectedTitleId,
    this.preselectedMediaType,
  });

  TwoToWatchArgs get _args => (
        friendId: friendId,
        friendHandle: friendHandle,
        friendDisplayName: friendDisplayName,
        titleId: preselectedTitleId,
        titleMediaType: preselectedMediaType,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = twoToWatchProvider(_args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final picks = state.readyForPicks ? state.recommendations.take(3).toList() : const <ScoredRecommendation>[];
    final canSwipe = state.readyForPicks && state.recommendations.length >= 2;

    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      appBar: const TellySubpageAppBar(nav: TellyNavKind.close, title: 'Two-to-Watch'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (state.preselected != null) ...[
            _PreselectedBanner(candidate: state.preselected!),
            const SizedBox(height: 16),
          ],
          _StepCard(
            key: const Key('cowatch_step_couch'),
            step: 1,
            title: "WHO'S WATCHING?",
            done: state.partner != null,
            child: _CouchStep(state: state, onPick: (p) => controller.selectPartner(p)),
          ),
          const SizedBox(height: 12),
          _StepCard(
            key: const Key('cowatch_step_mood'),
            step: 2,
            title: 'WHAT ARE YOU IN THE MOOD FOR?',
            done: state.vibes.isNotEmpty,
            child: _MoodStep(state: state, controller: controller),
          ),
          const SizedBox(height: 12),
          _StepCard(
            key: const Key('cowatch_step_picks'),
            step: 3,
            title: "TONIGHT'S TOP PICKS",
            done: picks.isNotEmpty,
            child: _PicksStep(state: state, picks: picks, onQueue: (c) => _queue(context, controller, c)),
          ),
          if (canSwipe) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('cowatch_quick_swipe_btn'),
              onPressed: () => _openQuickSwipe(context, ref, state),
              style: OutlinedButton.styleFrom(
                foregroundColor: TellyColors.primaryAccentOf(context),
                side: BorderSide(color: TellyColors.primaryAccentOf(context).withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.swipe, size: 18),
              label: Text(
                "Can't agree? 15-second Quick Swipe",
                style: TellyTypography.labelMedium(color: TellyColors.primaryAccentOf(context)).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _queue(BuildContext context, TwoToWatchController controller, CoWatchCandidate c) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.addToWatchlist(c);
      messenger.showSnackBar(SnackBar(content: Text('Added ${c.title} to your watchlist')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't add it. Try again.")));
    }
  }

  void _openQuickSwipe(BuildContext context, WidgetRef ref, TwoToWatchState state) {
    final partner = state.partner!;
    final myId = ref.read(authRepositoryProvider).currentUserId ?? 'me';
    final sorted = [myId, partner.userId]..sort();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => QuickSwipeDeckModal(
        // Spec 05 §3.2: both phones get the same five cards.
        candidates: [for (final r in state.recommendations.take(5)) r.candidate],
        friendHandle: '@${partner.username}',
        friendId: partner.userId,
        sessionId: 'cowatch-${sorted.join('-')}',
        sharedProviders: state.streaming.known ? state.activeProviders : const {},
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({super.key, required this.step, required this.title, required this.done, required this.child});

  final int step;
  final String title;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? TellyColors.phosphorLime : Colors.transparent,
                  border: Border.all(color: done ? TellyColors.phosphorLime : TellyColors.strokeStrongOf(context)),
                ),
                child: Text(
                  '$step',
                  style: TellyTypography.caption(
                    color: done ? (Theme.of(context).brightness == Brightness.light ? Colors.white : TellyColors.backgroundCanvasOled) : TellyColors.textTertiaryOf(context),
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TellyTypography.labelSmall(color: TellyColors.textPrimaryOf(context))
                      .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PreselectedBanner extends StatelessWidget {
  const _PreselectedBanner({required this.candidate});

  final CoWatchCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cowatch_preselected_badge'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TellyColors.electricViolet.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.electricViolet.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _Poster(path: candidate.posterPath, mediaType: candidate.mediaType, width: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Deciding on '),
                TextSpan(text: candidate.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const TextSpan(text: '? It stays at the top of your picks.'),
              ]),
              style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouchStep extends StatelessWidget {
  const _CouchStep({required this.state, required this.onPick});

  final TwoToWatchState state;
  final ValueChanged<CoWatchPartner> onPick;

  @override
  Widget build(BuildContext context) {
    final partner = state.partner;
    if (state.resolvingPartner) {
      return const _Loading();
    }
    if (partner != null) {
      final match = state.matchPercentage;
      return Row(
        children: [
          const _Avatar(label: 'You'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.add, size: 14, color: TellyColors.textTertiaryOf(context)),
          ),
          _Avatar(label: partner.label, url: partner.avatarUrl, accent: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800),
                ),
                if (partner.username.isNotEmpty)
                  Text('@${partner.username}', style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
              ],
            ),
          ),
          if (match != null) ...[
            TellyNeonBadge(
              key: const Key('cowatch_match_badge'),
              label: '$match% MATCH',
              variant: TellyBadgeVariant.tasteMatch,
            ),
            const SizedBox(width: 4),
          ],
          if ((state.partners ?? const []).length > 1)
            IconButton(
              key: const Key('cowatch_change_partner'),
              tooltip: 'Watch with someone else',
              icon: Icon(Icons.swap_horiz, color: TellyColors.textSecondaryOf(context)),
              onPressed: () => _showPicker(context),
            ),
        ],
      );
    }

    final partners = state.partners;
    if (partners == null) return const _Loading();
    if (partners.isEmpty) {
      return Text(
        'Follow friends to decide what to watch together.',
        style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
      );
    }
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: partners.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => InkWell(
          key: Key('cowatch_partner_${partners[i].username}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => onPick(partners[i]),
          child: SizedBox(
            width: 64,
            child: Column(
              children: [
                _Avatar(label: partners[i].label, url: partners[i].avatarUrl, radius: 24),
                const SizedBox(height: 6),
                Text(
                  partners[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TellyColors.cardOf(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (final p in state.partners ?? const <CoWatchPartner>[])
              ListTile(
                key: Key('cowatch_pick_${p.username}'),
                leading: _Avatar(label: p.label, url: p.avatarUrl),
                title: Text(p.label, style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context))),
                subtitle: Text('@${p.username}', style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
                trailing: p.userId == state.partner?.userId
                    ? const Icon(Icons.check, color: TellyColors.phosphorLime)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  onPick(p);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MoodStep extends StatelessWidget {
  const _MoodStep({required this.state, required this.controller});

  final TwoToWatchState state;
  final TwoToWatchController controller;

  @override
  Widget build(BuildContext context) {
    final shared = state.streaming.shared.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final (format, label) in const [
              (CoWatchFormat.movieNight, 'Movie Night'),
              (CoWatchFormat.series, 'TV Series'),
            ]) ...[
              Expanded(
                child: _Segment(
                  key: Key('cowatch_format_${format.mediaType}'),
                  label: label,
                  selected: state.format == format,
                  onTap: () => controller.selectFormat(format),
                ),
              ),
              if (format == CoWatchFormat.movieNight) const SizedBox(width: 8),
            ],
          ],
        ),
        if (state.format == CoWatchFormat.movieNight) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final budget in RuntimeBudget.values)
                _Chip(
                  label: budget.label,
                  selected: state.runtimeBudget == budget,
                  color: TellyColors.warmAmberOf(context),
                  onTap: () => controller.selectRuntime(state.runtimeBudget == budget ? null : budget),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final vibe in CoWatchVibe.values)
              _Chip(
                key: Key('cowatch_vibe_${vibe.id}'),
                label: vibe.label,
                selected: state.vibes.contains(vibe.id),
                color: TellyColors.electricVioletOf(context),
                onTap: () => controller.toggleVibe(vibe.id),
              ),
          ],
        ),
        if (state.streaming.known) ...[
          const SizedBox(height: 14),
          Text(
            shared.isEmpty ? 'No streaming services in common' : 'ON SERVICES YOU BOTH HAVE',
            style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(fontWeight: FontWeight.w700),
          ),
          if (shared.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in shared)
                  _Chip(
                    key: Key('cowatch_provider_$id'),
                    label: StreamingPlatform.labelFor(id),
                    selected: state.activeProviders.contains(id),
                    color: TellyColors.primaryAccentOf(context),
                    onTap: () => controller.toggleProvider(id),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _PicksStep extends StatelessWidget {
  const _PicksStep({required this.state, required this.picks, required this.onQueue});

  final TwoToWatchState state;
  final List<ScoredRecommendation> picks;
  final ValueChanged<CoWatchCandidate> onQueue;

  @override
  Widget build(BuildContext context) {
    if (state.partner == null) {
      return _Muted(state.resolvingPartner ? 'Finding your friend…' : "Pick who you're watching with first.");
    }
    if (state.vibes.isEmpty) {
      return const _Muted('Pick a vibe above to reveal tonight\'s top picks.', key: Key('cowatch_picks_locked'));
    }
    final pool = state.candidates;
    if (pool == null) return const _Loading();
    if (state.candidatesFailed) return const _Muted("Couldn't load picks. Check your connection and try again.");
    if (pool.isEmpty) {
      return const _Muted('Nothing on either of your queues yet. Queue a few titles and come back.');
    }
    if (picks.isEmpty) {
      return const _Muted('No picks match these filters. Try another vibe or runtime.');
    }
    return Column(children: [for (final rec in picks) _PickCard(rec: rec, onQueue: () => onQueue(rec.candidate))]);
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({required this.rec, required this.onQueue});

  final ScoredRecommendation rec;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final c = rec.candidate;
    final provider = rec.matchedProviders.firstOrNull;
    final meta = [
      if (c.network.isNotEmpty) c.network,
      if (c.runtimeMinutes != null) '${c.runtimeMinutes}m',
      if (c.communityScore > 0) '★ ${c.communityScore.toStringAsFixed(1)}',
    ].join(' • ');

    return InkWell(
      key: Key('cowatch_pick_${c.showId}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(Routes.title(c.mediaType, c.showId)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: TellyColors.cardOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TellyColors.borderGlassOf(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Poster(path: c.posterPath, mediaType: c.mediaType, width: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta, style: TellyTypography.caption(color: TellyColors.warmAmber)),
                  ],
                  const SizedBox(height: 6),
                  Text(rec.matchReason, style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))),
                  if (provider != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: Key('cowatch_watch_${c.showId}'),
                      onPressed: () => StreamingDeepLinkFactory.launchPlayback(
                        providerId: provider,
                        externalShowId: '${c.showId}',
                        showSlug: c.title.toLowerCase().replaceAll(' ', '-'),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: TellyColors.phosphorLime,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 48),
                        alignment: Alignment.centerLeft,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        'Watch on ${StreamingPlatform.labelFor(provider)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              key: Key('cowatch_queue_${c.showId}'),
              tooltip: c.inWatchlistA ? 'In your watchlist' : 'Add to Watchlist',
              onPressed: c.inWatchlistA ? null : onQueue,
              icon: Icon(
                c.inWatchlistA ? Icons.bookmark : Icons.bookmark_add_outlined,
                color: c.inWatchlistA ? TellyColors.phosphorLime : TellyColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.path, required this.mediaType, required this.width});

  final String? path;
  final String mediaType;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: width * 1.5,
        color: TellyColors.surfaceOf(context),
        child: PosterImage(
          posterPath: path,
          fallback: Center(
            child: Icon(
              mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
              size: width / 2.5,
              color: TellyColors.textTertiaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, this.url, this.accent = false, this.radius = 18});

  final String label;
  final String? url;
  final bool accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = label.replaceFirst('@', '');
    return CircleAvatar(
      radius: radius,
      backgroundColor: TellyColors.cardOf(context),
      foregroundImage: url != null && url!.isNotEmpty ? NetworkImage(url!) : null,
      child: Text(
        initial.isEmpty ? '?' : initial[0].toUpperCase(),
        style: TextStyle(
          color: accent ? TellyColors.primaryAccentOf(context) : TellyColors.textPrimaryOf(context),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : TellyColors.cardOf(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? accent : TellyColors.borderGlassOf(context)),
        ),
        child: Text(
          label,
          style: TellyTypography.labelLarge(
            color: selected
                ? (Theme.of(context).brightness == Brightness.light ? const Color(0xFF233B00) : accent)
                : TellyColors.textPrimaryOf(context),
          ).copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.selected, required this.color, required this.onTap});

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: TellyColors.cardOf(context),
      selectedColor: color.withValues(alpha: 0.18),
      side: BorderSide(color: selected ? color : TellyColors.borderGlassOf(context)),
      labelStyle: TextStyle(
        color: selected ? color : TellyColors.textPrimaryOf(context),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: TellyColors.primaryAccentOf(context)),
          ),
        ),
      );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)));
}
