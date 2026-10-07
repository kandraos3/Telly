import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../../squads/data/squad_repository.dart';
import '../../../squads/domain/squad_models.dart';
import '../../domain/challenge.dart';
import '../controllers/challenges_controller.dart';
import '../widgets/challenge_widgets.dart';
import '../widgets/squad_challenge_sheet.dart';

/// Squads I own or administer: the ones I can start a challenge in (§8.3).
final manageableSquadsProvider = FutureProvider.autoDispose<List<Squad>>((ref) async {
  try {
    final squads = await ref.watch(squadRepositoryProvider).mySquads();
    return [for (final s in squads) if (s.myRole == SquadRole.owner || s.myRole == SquadRole.admin) s];
  } catch (_) {
    return const [];
  }
});

/// `SCR-25` Challenges (`/more/challenges`, features/10 §9.5, mockup C1; #144): the featured
/// hero, Yours, Join next, and Ended (collapsed). "+" lets squad owners and admins start one.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(challengesControllerProvider);
    final overview = async.valueOrNull;
    final squads = ref.watch(manageableSquadsProvider).valueOrNull ?? const <Squad>[];
    return Scaffold(
      appBar: TellySubpageAppBar(
        title: 'Challenges',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.more),
        actions: [
          if (squads.isNotEmpty)
            TellyHeaderAction(
              key: const Key('challenges_create'),
              icon: Icons.add_rounded,
              tooltip: 'Start a squad challenge',
              onPressed: () => SquadChallengeSheet.show(context, squads),
            ),
        ],
      ),
      body: SafeArea(
        child: overview != null
            ? RefreshIndicator(
                color: TellyColors.primaryAccentOf(context),
                onRefresh: () => ref.refresh(challengesControllerProvider.future),
                child: _Body(overview: overview),
              )
            : async.hasError
                ? Center(
                    child: TellyEmptyState(
                      key: const Key('challenges_error'),
                      icon: Icons.flag_outlined,
                      title: "Couldn't load challenges",
                      message: 'Check your connection and try again.',
                      actionLabel: 'Retry',
                      actionIcon: Icons.refresh_rounded,
                      onAction: () => ref.invalidate(challengesControllerProvider),
                    ),
                  )
                : const _Skeleton(),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final ChallengesOverview overview;
  const _Body({required this.overview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(challengeClockProvider)();
    if (overview.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          TellyEmptyState(
            key: Key('challenges_empty'),
            icon: Icons.flag_outlined,
            title: 'No challenges right now',
            message: 'New ones start every month. Check back soon.',
          ),
        ],
      );
    }
    return ListView(
      key: const Key('challenges_list'),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        if (overview.featured case final featured?) _Hero(challenge: featured, now: now),
        if (overview.yours.isNotEmpty) ...[
          const SizedBox(height: 22),
          const TellySectionHeader(label: 'Yours'),
          const SizedBox(height: 10),
          _Card(
            key: const Key('challenges_section_yours'),
            children: [for (final c in overview.yours) _ChallengeRow(challenge: c, now: now)],
          ),
        ],
        if (overview.joinNext.isNotEmpty) ...[
          const SizedBox(height: 22),
          const TellySectionHeader(label: 'Join next'),
          const SizedBox(height: 10),
          _Card(
            key: const Key('challenges_section_join_next'),
            children: [for (final c in overview.joinNext) _ChallengeRow(challenge: c, now: now)],
          ),
        ],
        if (overview.ended.isNotEmpty) ...[
          const SizedBox(height: 22),
          _Ended(challenges: overview.ended, now: now),
        ],
      ],
    );
  }
}

Future<void> _join(BuildContext context, WidgetRef ref, Challenge c) async {
  HapticsService.lightImpact();
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await ref.read(challengesControllerProvider.notifier).join(c);
    messenger?.showSnackBar(SnackBar(content: Text('Joined ${c.name}')));
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(content: Text("Couldn't join. Try again.")));
  }
}

String _joinedLine(Challenge c) {
  final joined = '${c.participantCount} joined';
  if (c.friendCount == 0) return joined;
  return '$joined · ${c.friendCount} ${c.friendCount == 1 ? 'friend' : 'friends'}';
}

/// The featured challenge: art, "FEATURED · N DAYS LEFT", name, rule line, counts, and my
/// progress or Join.
class _Hero extends ConsumerWidget {
  final Challenge challenge;
  final DateTime now;
  const _Hero({required this.challenge, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = challenge;
    final days = c.daysLeft(now);
    final eyebrow = days == null ? 'FEATURED · OPEN-ENDED' : 'FEATURED · ${c.timeLabel(now).toUpperCase()}';
    return Semantics(
      button: true,
      label: 'Featured challenge, ${c.name}. ${c.description}',
      child: GestureDetector(
        key: const Key('challenges_featured'),
        onTap: () => context.push(Routes.challenge(c.slug)),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: ChallengeArt.of(c.art),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TellyColors.borderGlassOf(context)),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xED08090C)],
                stops: [0.15, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(eyebrow,
                      style: TellyTypography.labelSmall(color: TellyColors.phosphorLime)
                          .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                  const SizedBox(height: 4),
                  Text(c.name,
                      style: TellyTypography.titleLarge(color: Colors.white).copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${c.description} · ${_joinedLine(c)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.caption(color: TellyColors.textSecondary)),
                  const SizedBox(height: 10),
                  if (c.joined)
                    Row(
                      children: [
                        Text('You: ${c.myProgress} of ${c.target}',
                            style: TellyTypography.labelMedium(color: Colors.white).copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 10),
                        Expanded(child: ChallengeBar(value: c.fraction, done: c.isCompleted)),
                      ],
                    )
                  else
                    LimePill(key: const Key('challenges_featured_join'), label: 'Join', onTap: () => _join(context, ref, c)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({super.key, required this.children});

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

/// A challenge in a list: medal, name, subtitle, and progress (joined) or Join.
class _ChallengeRow extends ConsumerWidget {
  final Challenge challenge;
  final DateTime now;
  const _ChallengeRow({required this.challenge, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = challenge;
    final subtitle = [
      if (c.isSquad) 'Squad · ${c.squadName ?? ''}',
      if (!c.joined) c.description,
      c.hasEnded(now) ? (c.isCompleted ? 'Finished' : '${c.myProgress} of ${c.target}') : c.timeLabel(now),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: Key('challenge_row_${c.slug}'),
        onTap: () => context.push(Routes.challenge(c.slug)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              ChallengeMedal(challenge: c),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))),
                    if (c.joined && !c.hasEnded(now)) ...[
                      const SizedBox(height: 6),
                      ChallengeBar(value: c.fraction, done: c.isCompleted, height: 5),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (c.isSquad) ...[const OutlineChip(label: 'Squad'), const SizedBox(width: 8)],
              if (c.joined)
                Text('${c.myProgress}/${c.target}',
                    key: Key('challenge_progress_${c.slug}'),
                    style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context))
                        .copyWith(fontWeight: FontWeight.w700))
              else
                LimePill(key: Key('challenge_join_${c.slug}'), label: 'Join', onTap: () => _join(context, ref, c)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ended challenges, collapsed until opened; finished ones show their medal.
class _Ended extends StatefulWidget {
  final List<Challenge> challenges;
  final DateTime now;
  const _Ended({required this.challenges, required this.now});

  @override
  State<_Ended> createState() => _EndedState();
}

class _EndedState extends State<_Ended> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('challenges_ended_toggle'),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Expanded(child: TellySectionHeader(label: 'Ended · ${widget.challenges.length}')),
                Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: TellyColors.textTertiaryOf(context)),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 10),
          _Card(
            key: const Key('challenges_section_ended'),
            children: [for (final c in widget.challenges) _ChallengeRow(challenge: c, now: widget.now)],
          ),
        ],
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: TellyColors.surfaceOf(context), borderRadius: BorderRadius.circular(16)),
        );
    return ListView(
      key: const Key('challenges_skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      children: [block(190), block(130), block(130)],
    );
  }
}
