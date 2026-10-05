import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/poster_image.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_canon_switcher.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_neon_badge.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../../../core/widgets/telly_segmented_control.dart';
import '../../data/squad_repository.dart';
import '../../domain/squad_models.dart';
import '../controllers/squad_controllers.dart';
import 'squads_list_screen.dart';

/// SCR-17b: Squads Hub & Consensus Leaderboard (FE-306, FE-608; redesigned in FE-SQUADS-04).
///
/// Members come from `get_squad_members`, the leaderboard from `calculate_squad_canon`
/// (Borda count, per canon), the Squad Watchlist from `squad_shared_watchlist`.
class SquadHubScreen extends ConsumerWidget {
  final String squadId;

  const SquadHubScreen({super.key, required this.squadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(squadHubProvider(squadId));
    final hub = async.valueOrNull;

    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      appBar: TellySubpageAppBar(
        title: hub?.squad.name ?? 'Squad',
        subtitle: hub == null ? null : '${hub.squad.memberCount} ${hub.squad.memberCount == 1 ? 'member' : 'members'}',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.squads),
        actions: [
          if (hub != null && ref.read(squadHubProvider(squadId).notifier).canInvite)
            TellyHeaderAction(
              key: const Key('squad_invite_button'),
              icon: Icons.person_add_outlined,
              tooltip: 'Invite',
              onPressed: () => _invite(context, ref),
            ),
          if (hub != null)
            TellyHeaderMenu<String>(
              key: const Key('squad_menu_button'),
              tooltip: 'Squad options',
              onSelected: (_) => _deleteOrLeave(context, ref),
              itemBuilder: (_) {
                final owner = ref.read(squadHubProvider(squadId).notifier).isOwner;
                return [
                  PopupMenuItem(
                    key: Key(owner ? 'squad_delete' : 'squad_leave'),
                    value: owner ? 'delete' : 'leave',
                    child: Row(children: [
                      Icon(owner ? Icons.delete_forever_rounded : Icons.logout_rounded,
                          color: TellyColors.neonCoralOf(context), size: 20),
                      const SizedBox(width: 12),
                      Text(owner ? 'Delete Squad' : 'Leave Squad',
                          style: TellyTypography.bodyMedium(color: TellyColors.neonCoralOf(context))),
                    ]),
                  ),
                ];
              },
            ),
        ],
      ),
      body: SafeArea(
        child: switch (async) {
          AsyncData(:final value) => _Hub(squadId: squadId, hub: value),
          AsyncError() => Center(
              key: const Key('squad_error'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Couldn't load this squad.", style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))),
                  TextButton(onPressed: () => ref.invalidate(squadHubProvider(squadId)), child: const Text('Retry')),
                ],
              ),
            ),
          _ => Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
        },
      ),
    );
  }

  Future<void> _deleteOrLeave(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(squadHubProvider(squadId).notifier);
    final owner = controller.isOwner;
    final name = ref.read(squadHubProvider(squadId)).valueOrNull?.squad.name ?? 'this squad';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TellyColors.cardOf(context),
        title: Text(owner ? 'Delete $name?' : 'Leave $name?', style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
        content: Text(
          owner
              ? 'This permanently removes the squad, its leaderboard and its watchlist for every member.'
              : "You'll stop seeing this squad's leaderboard and watchlist. An admin can invite you back.",
          style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
        ),
        actions: [
          TextButton(
            key: const Key('squad_destructive_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('squad_destructive_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(owner ? 'Delete' : 'Leave', style: const TextStyle(color: TellyColors.neonCoral)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await controller.deleteOrLeave();
      HapticsService.mediumImpact();
      messenger.showSnackBar(SnackBar(content: Text(owner ? 'Deleted $name' : 'You left $name')));
      router.go(Routes.squads);
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(owner ? "Couldn't delete the squad. Try again." : "Couldn't leave the squad. Try again.")));
    }
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    HapticsService.lightImpact();
    final controller = ref.read(squadHubProvider(squadId).notifier);
    final query = await showDialog<String>(
      context: context,
      builder: (_) => _InviteDialog(check: controller.checkInvitee),
    );
    if (query == null || query.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final invitee = await controller.invite(query);
      HapticsService.mediumImpact();
      messenger.showSnackBar(SnackBar(content: Text('Added @${invitee.username}')));
    } on InviteFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't add them. Try again.")));
    }
  }
}

/// Invite by handle or email with live validation (FE-SQUADS-02). Pops the typed query
/// once it resolves to someone who can join.
class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.check});

  final Future<InviteCheck> Function(String query) check;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  static const _debounce = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  Timer? _timer;
  bool _checking = false;
  InviteCheck _result = const InviteCheck.empty();

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _checking = false;
        _result = const InviteCheck.empty();
      });
      return;
    }
    setState(() => _checking = true);
    _timer = Timer(_debounce, () async {
      final result = await widget.check(value);
      // Drop answers for text the user has since changed.
      if (!mounted || _controller.text != value) return;
      setState(() {
        _checking = false;
        _result = result;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final invitee = _checking ? null : _result.invitee;
    return AlertDialog(
      backgroundColor: TellyColors.cardOf(context),
      title: Text('Invite to squad', style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('squad_invite_field'),
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: '@handle or email',
              suffixIcon: _checking
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: TellyColors.textTertiaryOf(context)),
                      ),
                    )
                  : invitee != null
                      ? Icon(Icons.check_circle, key: const Key('squad_invite_valid'), color: TellyColors.primaryAccentOf(context))
                      : _result.error != null
                          ? Icon(Icons.error_outline, key: const Key('squad_invite_invalid'), color: TellyColors.neonCoralOf(context))
                          : null,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 20,
            child: invitee != null
                ? Text(
                    '${invitee.displayName.isEmpty ? '@${invitee.username}' : invitee.displayName} · @${invitee.username}',
                    key: const Key('squad_invite_match'),
                    style: TellyTypography.caption(color: TellyColors.primaryAccentOf(context)).copyWith(fontWeight: FontWeight.w700),
                  )
                : !_checking && _result.error != null
                    ? Text(
                        _result.error!,
                        key: const Key('squad_invite_error'),
                        style: TellyTypography.caption(color: TellyColors.neonCoralOf(context)),
                      )
                    : null,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          key: const Key('squad_invite_confirm'),
          onPressed: invitee == null ? null : () => Navigator.of(context).pop(_controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// SCR-17b body (FE-SQUADS-04): hero, section tabs, canon switcher, then the tab.
class _Hub extends ConsumerWidget {
  final String squadId;
  final SquadHubState hub;
  const _Hub({required this.squadId, required this.hub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(squadHubProvider(squadId).notifier);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        _SquadHero(hub: hub),
        TellySegmentedControl<SquadTab>(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          segments: const [
            TellySegment(value: SquadTab.consensus, label: 'Consensus', key: Key('squad_tab_consensus')),
            TellySegment(value: SquadTab.watchlist, label: 'Watchlist', key: Key('squad_tab_watchlist')),
            TellySegment(value: SquadTab.debates, label: 'Debates', key: Key('squad_tab_debates')),
          ],
          selected: hub.tab,
          onChanged: controller.selectTab,
        ),
        if (hub.tab != SquadTab.watchlist) ...[
          TellyCanonSwitcher(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            selected: hub.mediaType,
            movieKey: const Key('squad_canon_movie'),
            seriesKey: const Key('squad_canon_tv'),
            onSelect: (mediaType) {
              HapticsService.selectionClick();
              controller.selectCanon(mediaType);
            },
          ),
        ],
        const SizedBox(height: 16),
        if (hub.loadingCanon)
          const _Spinner()
        else
          ...switch (hub.tab) {
            SquadTab.consensus => _consensus(context, hub),
            SquadTab.watchlist => _watchlist(hub),
            SquadTab.debates => _debates(hub),
          },
      ],
    );
  }

  static String _canonNoun(String mediaType) => mediaType == 'movie' ? 'movie' : 'show';

  List<Widget> _consensus(BuildContext context, SquadHubState hub) {
    final board = hub.leaderboard;
    if (board.isEmpty) {
      return [
        TellyEmptyState(
          key: const Key('squad_consensus_empty'),
          icon: Icons.leaderboard_outlined,
          title: 'Nothing ranked together yet',
          message: 'Once members rank a ${_canonNoun(hub.mediaType)}, the squad’s consensus canon appears here.',
          actionLabel: 'Rank a title',
          actionIcon: Icons.add_rounded,
          onAction: () => context.push(Routes.log),
        ),
      ];
    }
    final podium = board.take(3).toList();
    final rest = board.skip(3).toList();
    final hotDebate = hub.debates.firstOrNull;
    final members = hub.squad.memberCount;
    return [
      const TellySectionHeader(label: 'SQUAD TOP 3'),
      const SizedBox(height: 10),
      _Podium(items: podium),
      if (hotDebate != null) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DebateCard(item: hotDebate, headline: 'Biggest debate'),
        ),
      ],
      if (rest.isNotEmpty) ...[
        const SizedBox(height: 20),
        TellySectionHeader(
          label: 'THE RANKING',
          trailing: Text(
            '${board.length} titles',
            style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        for (final item in rest) _ConsensusRow(item: item, memberCount: members),
      ],
    ];
  }

  List<Widget> _watchlist(SquadHubState hub) {
    final list = hub.watchlist;
    if (list == null) return const [_Spinner()];
    if (list.isEmpty) {
      return const [
        TellyEmptyState(
          key: Key('squad_watchlist_empty'),
          icon: Icons.bookmark_outline,
          title: 'No shared picks yet',
          message: 'Titles on more than one member’s queue show up here.',
        ),
      ];
    }
    return [
      TellySectionHeader(label: 'WANT TO WATCH (${list.length})'),
      const SizedBox(height: 10),
      for (final item in list) _WatchlistCard(item: item),
    ];
  }

  List<Widget> _debates(SquadHubState hub) {
    if (hub.debates.isEmpty) {
      return const [
        TellyEmptyState(
          key: Key('squad_debates_empty'),
          icon: Icons.local_fire_department_outlined,
          title: 'No debates yet',
          message: 'No big disagreements in this canon. Yet.',
        ),
      ];
    }
    return [
      TellySectionHeader(label: 'DEBATES (${hub.debates.length})'),
      const SizedBox(height: 10),
      for (final item in hub.debates)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _DebateCard(item: item),
        ),
    ];
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
      );
}

/// Squad identity card, like the Canon's profile card (FE-SQUADS-04): monogram, name,
/// description, member faces (tap for the full list) and quick counts for the canon shown.
class _SquadHero extends StatelessWidget {
  final SquadHubState hub;
  const _SquadHero({required this.hub});

  @override
  Widget build(BuildContext context) {
    final squad = hub.squad;
    final description = squad.description;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              SquadMonogram(squad: squad, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      squad.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.titleLarge(color: TellyColors.textPrimaryOf(context))
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: 'See all ${squad.memberCount} members',
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const Key('squad_members_button'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showMembers(context, squad.members),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      TellyAvatarStack(
                        people: [for (final m in squad.members) (_name(m), m.avatarUrl)],
                        total: squad.memberCount,
                        max: 5,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _membersLine(squad.members, squad.memberCount),
                          key: const Key('squad_members_line'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context))
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: TellyColors.textTertiaryOf(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: TellyColors.borderGlassOf(context)),
          ),
          Row(
            children: [
              _Stat(
                  key: const Key('squad_stat_members'),
                  value: '${squad.memberCount}',
                  label: squad.memberCount == 1 ? 'Member' : 'Members'),
              _Stat(
                  key: const Key('squad_stat_titles'),
                  value: hub.loadingCanon ? '–' : '${hub.leaderboard.length}',
                  label: 'Ranked together'),
              _Stat(
                  key: const Key('squad_stat_debates'),
                  value: hub.loadingCanon ? '–' : '${hub.debates.length}',
                  label: 'Debates',
                  hot: hub.debates.isNotEmpty),
            ],
          ),
        ],
      ),
    );
  }

  static String _name(SquadMember m) => m.displayName.isEmpty ? '@${m.username}' : m.displayName;

  /// "Jordan", "Jordan and Alex", "Jordan, Alex and Sam", or "Jordan and 4 others" (fits a phone).
  static String _membersLine(List<SquadMember> members, int total) {
    final names = [for (final m in members) _name(m)];
    if (names.isEmpty) return '$total ${total == 1 ? 'member' : 'members'}';
    if (names.length == total && total <= 3) {
      return names.length == 1 ? names.single : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    }
    final others = total - 1;
    return '${names.first} and $others ${others == 1 ? 'other' : 'others'}';
  }

  void _showMembers(BuildContext context, List<SquadMember> members) {
    HapticsService.selectionClick();
    TellyFrostedSheet.show<void>(
      context: context,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Members (${members.length})',
                style: TellyTypography.subpageTitle(color: TellyColors.textPrimaryOf(sheetContext))),
            const SizedBox(height: 8),
            Flexible(
              // Own Material, so row ripples show above the frosted sheet's fill.
              child: Material(
                type: MaterialType.transparency,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in members)
                      ListTile(
                        key: Key('squad_member_${m.userId}'),
                        contentPadding: EdgeInsets.zero,
                        leading: TellyAvatar(name: _name(m), imageUrl: m.avatarUrl, radius: 20),
                        title: Text(_name(m),
                            style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(sheetContext))
                                .copyWith(fontWeight: FontWeight.w700)),
                        subtitle: m.username.isEmpty
                            ? null
                            : Text('@${m.username}',
                                style: TellyTypography.caption(color: TellyColors.textSecondaryOf(sheetContext))),
                        trailing: m.role == SquadRole.member ? null : SquadRoleBadge(role: m.role),
                        onTap: m.username.isEmpty
                            ? null
                            : () {
                                Navigator.of(sheetContext).pop();
                                context.push(Routes.profile(m.username));
                              },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool hot;
  const _Stat({super.key, required this.value, required this.label, this.hot = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TellyTypography.scoreChip(
                      color: hot ? TellyColors.neonCoralOf(context) : TellyColors.textPrimaryOf(context))
                  .copyWith(fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

Widget _posterFallback(BuildContext context, String mediaType, {double size = 24}) => Center(
      child: Icon(
        mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
        color: TellyColors.textTertiaryOf(context),
        size: size,
      ),
    );

/// The squad's top three as poster cards, like the Canon's Top 3 Showcase (FE-SQUADS-04).
class _Podium extends StatelessWidget {
  final List<SquadConsensusItem> items;
  const _Podium({required this.items});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                  child: i < items.length ? _PodiumCard(item: items[i]) : _PodiumGap(rank: i + 1),
                ),
              ),
          ],
        ),
      );
}

class _PodiumCard extends StatelessWidget {
  final SquadConsensusItem item;
  const _PodiumCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final first = item.consensusRank == 1;
    final accent = TellyColors.primaryAccentOf(context);
    final onAccent = Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF08090C);
    return Semantics(
      button: true,
      label: '#${item.consensusRank} ${item.title}, ${item.totalBordaPoints} points',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('squad_consensus_${item.titleId}'),
        onTap: () => context.push(Routes.title(item.mediaType, item.titleId)),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: TellyColors.cardOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: first ? accent.withValues(alpha: 0.6) : TellyColors.borderGlassOf(context),
              width: first ? 1.5 : 1,
            ),
            boxShadow: first ? [BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 14)] : null,
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      color: TellyColors.surfaceOf(context),
                      child:
                          PosterImage(posterPath: item.posterUrl, fallback: _posterFallback(context, item.mediaType)),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: first ? accent : TellyColors.cardOf(context).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${item.consensusRank}',
                        style: TellyTypography.caption(color: first ? onAccent : TellyColors.textPrimaryOf(context))
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TellyTypography.caption(color: TellyColors.textPrimaryOf(context))
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.totalBordaPoints} pts',
                style: TellyTypography.scoreMono(color: first ? accent : TellyColors.textSecondaryOf(context))
                    .copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PodiumGap extends StatelessWidget {
  final int rank;
  const _PodiumGap({required this.rank});

  @override
  Widget build(BuildContext context) => Container(
        height: 160,
        decoration: BoxDecoration(
          color: TellyColors.cardOf(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TellyColors.strokeSubtleOf(context)),
        ),
        alignment: Alignment.center,
        child: Text('#$rank', style: TellyTypography.titleMedium(color: TellyColors.textSecondaryOf(context))),
      );
}

/// A Borda-count row from #4 down, in the Canon's ranked-row style (FE-SQUADS-04).
class _ConsensusRow extends StatelessWidget {
  final SquadConsensusItem item;
  final int memberCount;
  const _ConsensusRow({required this.item, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final secondary = TellyColors.textSecondaryOf(context);
    return GestureDetector(
      key: Key('squad_consensus_${item.titleId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(Routes.title(item.mediaType, item.titleId)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: TellyColors.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TellyColors.borderGlassOf(context)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Text('#${item.consensusRank}',
                  style: TellyTypography.scoreChip(color: secondary).copyWith(fontSize: 15)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 36,
                height: 52,
                child: PosterImage(
                    posterPath: item.posterUrl, fallback: _posterFallback(context, item.mediaType, size: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  // Who ranks it highest (trophy) and lowest (down arrow) in the squad.
                  Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 13, color: TellyColors.warmAmberOf(context)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '${item.championDisplayName} #${item.championRank}',
                          key: const Key('squad_row_champion'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TellyTypography.caption(color: secondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_downward_rounded, size: 13, color: TellyColors.neonCoralOf(context)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '${item.lowestDisplayName} #${item.lowestRank}',
                          key: const Key('squad_row_lowest'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TellyTypography.caption(color: secondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ranked by ${item.membersRankedCount} of $memberCount',
                    style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.totalBordaPoints} pts',
              style: TellyTypography.scoreMono(color: TellyColors.primaryAccentOf(context)).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// A title the squad disagrees about (FE-SQUADS-04), in the Feed's upset styling.
class _DebateCard extends StatelessWidget {
  final SquadConsensusItem item;

  /// Optional label above the title ("Biggest debate" on the Consensus tab).
  final String? headline;
  const _DebateCard({required this.item, this.headline});

  @override
  Widget build(BuildContext context) {
    final coral = TellyColors.neonCoralOf(context);
    final gap = (item.lowestRank - item.championRank).abs();
    final secondary = TellyColors.textSecondaryOf(context);
    return GestureDetector(
      key: Key('squad_debate_${item.titleId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(Routes.title(item.mediaType, item.titleId)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(coral.withValues(alpha: 0.06), TellyColors.surfaceOf(context)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: coral.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 66,
                child: PosterImage(
                    posterPath: item.posterUrl, fallback: _posterFallback(context, item.mediaType, size: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TellyNeonBadge(
                    label: headline ?? 'Debate',
                    color: coral,
                    enableGlow: false,
                    icon: Icon(Icons.local_fire_department_rounded, size: 13, color: coral),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.championDisplayName} #${item.championRank}  vs  ${item.lowestDisplayName} #${item.lowestRank}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.caption(color: secondary).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text('$gap', style: TellyTypography.scoreChip(color: coral).copyWith(fontSize: 20)),
                Text('ranks apart',
                    style:
                        TellyTypography.caption(color: secondary).copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A title several members want to watch, in the Queue card style (FE-SQUADS-04).
class _WatchlistCard extends StatelessWidget {
  final SharedWatchlistItem item;
  const _WatchlistCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = TellyColors.primaryAccentOf(context);
    final share = item.memberCount == 0 ? 0.0 : (item.queuedBy / item.memberCount).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.everyone ? accent.withValues(alpha: 0.5) : TellyColors.borderGlassOf(context)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('squad_watch_${item.mediaType}_${item.titleId}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(Routes.title(item.mediaType, item.titleId)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 52,
                    height: 72,
                    color: TellyColors.cardOf(context),
                    child: PosterImage(
                        posterPath: item.posterUrl, fallback: _posterFallback(context, item.mediaType, size: 28)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                                  .copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (item.everyone) ...[
                            const SizedBox(width: 8),
                            TellyNeonBadge(
                              label: 'Everyone',
                              color: accent,
                              enableGlow: false,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.mediaType == 'movie' ? 'Movie' : 'TV show',
                        style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: share,
                          minHeight: 5,
                          color: accent,
                          backgroundColor: TellyColors.cardOf(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.everyone
                            ? 'Everyone wants to watch'
                            : '${item.queuedBy} of ${item.memberCount} want to watch',
                        style: TellyTypography.caption(
                                color: item.everyone ? accent : TellyColors.textSecondaryOf(context))
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
