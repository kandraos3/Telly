import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../../queue/data/watchlist_repository.dart';
import '../../../sharing/data/story_share_service.dart';
import '../../domain/challenge.dart';
import '../controllers/challenges_controller.dart';
import '../widgets/challenge_widgets.dart';

/// `SCR-26` Challenge (`/more/challenges/:slug`, features/10 §9.6, mockup C2; #144): the
/// progress card, friends racing, and picks that would count (Queue first). Join sits on the
/// card until joined; then Leave moves to the app bar's ⋮ menu.
class ChallengeScreen extends ConsumerWidget {
  final String slug;
  const ChallengeScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(challengeDetailProvider(slug));
    final detail = async.valueOrNull;
    final c = detail?.challenge;
    return Scaffold(
      appBar: TellySubpageAppBar(
        title: c?.name ?? 'Challenge',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.challenges),
        actions: [
          if (c != null)
            TellyHeaderAction(
              key: const Key('challenge_share'),
              icon: Icons.ios_share_rounded,
              tooltip: 'Share',
              onPressed: () => ref
                  .read(storyShareServiceProvider)
                  .shareChallenge(name: c.name, description: c.description, slug: c.slug),
            ),
          if (c != null && c.joined && !c.isCompleted)
            PopupMenuButton<String>(
              key: const Key('challenge_menu'),
              icon: Icon(Icons.more_vert_rounded, color: TellyColors.textSecondaryOf(context)),
              onSelected: (_) => _leave(context, ref, c),
              itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Leave challenge'))],
            ),
        ],
      ),
      body: SafeArea(
        child: detail != null
            ? RefreshIndicator(
                color: TellyColors.primaryAccentOf(context),
                onRefresh: () => ref.refresh(challengeDetailProvider(slug).future),
                child: _Body(detail: detail),
              )
            : async.hasError
                ? Center(
                    child: TellyEmptyState(
                      key: const Key('challenge_error'),
                      icon: Icons.flag_outlined,
                      title: async.error is ChallengeNotFound ? 'Challenge not found' : "Couldn't load this challenge",
                      message: async.error is ChallengeNotFound
                          ? 'It may have ended, or it belongs to a squad you are not in.'
                          : 'Check your connection and try again.',
                      actionLabel: 'Retry',
                      actionIcon: Icons.refresh_rounded,
                      onAction: () => ref.invalidate(challengeDetailProvider(slug)),
                    ),
                  )
                : Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Challenge c) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(challengesControllerProvider.notifier).leave(c);
      messenger?.showSnackBar(SnackBar(content: Text('Left ${c.name}')));
    } catch (_) {
      messenger?.showSnackBar(const SnackBar(content: Text("Couldn't leave. Try again.")));
    }
  }
}

class _Body extends ConsumerWidget {
  final ChallengeDetail detail;
  const _Body({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = detail.challenge;
    final now = ref.watch(challengeClockProvider)();
    final queued = [for (final p in detail.picks) if (p.fromQueue) p];
    final suggested = [for (final p in detail.picks) if (!p.fromQueue) p];
    return ListView(
      key: const Key('challenge_body'),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        _ProgressCard(challenge: c, now: now),
        if (detail.racers.isNotEmpty) ...[
          const SizedBox(height: 22),
          const TellySectionHeader(label: 'Friends in this challenge'),
          const SizedBox(height: 10),
          _Panel(
            key: const Key('challenge_racers'),
            children: [for (final r in detail.racers) _RacerRow(racer: r, target: c.target)],
          ),
        ],
        if (queued.isNotEmpty) ...[
          const SizedBox(height: 22),
          const TellySectionHeader(label: 'Picks from your Queue'),
          const SizedBox(height: 10),
          _Panel(
            key: const Key('challenge_picks_queue'),
            children: [for (final p in queued) _PickRow(pick: p)],
          ),
        ],
        if (suggested.isNotEmpty) ...[
          const SizedBox(height: 22),
          const TellySectionHeader(label: 'Friends rate these'),
          const SizedBox(height: 10),
          _Panel(
            key: const Key('challenge_picks_friends'),
            children: [for (final p in suggested) _PickRow(pick: p)],
          ),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: TellyColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TellyColors.strokeOf(context)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: TellyColors.strokeOf(context)),
              children[i],
            ],
          ],
        ),
      );
}

/// The rule line, time left, a large "3 / 8" and a bar; Join until joined.
class _ProgressCard extends ConsumerWidget {
  final Challenge challenge;
  final DateTime now;
  const _ProgressCard({required this.challenge, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = challenge;
    final muted = TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context));
    return Container(
      key: const Key('challenge_progress_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.strokeOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.description,
                    style: TellyTypography.bodyLarge(color: TellyColors.textSecondaryOf(context))),
              ),
              const SizedBox(width: 10),
              Text(c.timeLabel(now), key: const Key('challenge_time_left'), style: muted),
            ],
          ),
          if (c.isSquad) ...[
            const SizedBox(height: 6),
            Text('Squad · ${c.squadName ?? ''}', style: muted),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ChallengeMedal(challenge: c),
              const SizedBox(width: 12),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '${c.myProgress}',
                    style: TellyTypography.titleLarge(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontSize: 34, fontWeight: FontWeight.w800, height: 1),
                  ),
                  TextSpan(text: ' / ${c.target}', style: muted.copyWith(fontSize: 18)),
                ]),
                key: const Key('challenge_count'),
              ),
              const Spacer(),
              if (c.isCompleted)
                Text('Finished',
                    style: TellyTypography.labelMedium(color: TellyColors.warmAmberOf(context))
                        .copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ChallengeBar(value: c.fraction, done: c.isCompleted),
          if (!c.joined && !c.hasEnded(now)) ...[
            const SizedBox(height: 16),
            TellyPrimaryButton(
              key: const Key('challenge_join'),
              label: 'Join challenge',
              onPressed: () async {
                HapticsService.lightImpact();
                final messenger = ScaffoldMessenger.maybeOf(context);
                try {
                  await ref.read(challengesControllerProvider.notifier).join(c);
                } catch (_) {
                  messenger?.showSnackBar(const SnackBar(content: Text("Couldn't join. Try again.")));
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RacerRow extends StatelessWidget {
  final ChallengeRacer racer;
  final int target;
  const _RacerRow({required this.racer, required this.target});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: racer.isMe ? TellyColors.primaryAccentOf(context).withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          TellyAvatar(name: racer.name, imageUrl: racer.avatarUrl, radius: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(racer.name,
                    style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ChallengeBar(value: target == 0 ? 0 : racer.progress / target, done: racer.completedAt != null, height: 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${racer.progress}',
              style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))
                  .copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// A title that would count: "In your Queue", or what friends rate it, with + Queue.
class _PickRow extends ConsumerStatefulWidget {
  final ChallengePick pick;
  const _PickRow({required this.pick});

  @override
  ConsumerState<_PickRow> createState() => _PickRowState();
}

class _PickRowState extends ConsumerState<_PickRow> {
  bool _queued = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pick;
    final line = p.fromQueue
        ? 'In your Queue'
        : [
            if (p.releaseYear != null) '${p.releaseYear}',
            if (p.friendsScore != null)
              'Friends rate it ${p.friendsScore!.toStringAsFixed(1)}${p.friendCount > 1 ? ' (${p.friendCount})' : ''}',
          ].join(' · ');
    return InkWell(
      key: Key('challenge_pick_${p.titleId}'),
      onTap: () => context.push(Routes.title(p.mediaType, p.titleId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 50,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: TellyColors.cardOf(context), borderRadius: BorderRadius.circular(6)),
              child: PosterImage(
                posterPath: p.posterPath,
                fallback: Icon(p.mediaType == 'movie' ? Icons.movie_rounded : Icons.tv_rounded,
                    size: 16, color: TellyColors.textTertiaryOf(context)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(line, style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
                ],
              ),
            ),
            if (!p.fromQueue)
              _queued
                  ? Text('✓ In Queue', style: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context)))
                  : LimePill(key: Key('challenge_pick_queue_${p.titleId}'), label: '+ Queue', onTap: _queue),
          ],
        ),
      ),
    );
  }

  Future<void> _queue() async {
    final p = widget.pick;
    HapticsService.lightImpact();
    setState(() => _queued = true);
    try {
      await ref
          .read(watchlistRepositoryProvider)
          .add(titleId: p.titleId, mediaType: p.mediaType, title: p.title, posterPath: p.posterPath);
    } catch (_) {
      if (mounted) setState(() => _queued = false);
    }
  }
}
