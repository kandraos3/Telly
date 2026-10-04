import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../data/squad_repository.dart';
import '../../domain/squad_models.dart';
import '../controllers/squad_controllers.dart';

/// SCR-17: Squads Hub & Consensus Leaderboard (FE-306, FE-608).
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
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TellyColors.textPrimary),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.squads),
        ),
        title: Text(
          hub == null ? 'SQUAD' : '${hub.squad.name.toUpperCase()} (${hub.squad.memberCount})',
          style: TellyTypography.labelLarge(color: TellyColors.textPrimary)
              .copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (hub != null && ref.read(squadHubProvider(squadId).notifier).canInvite)
            TextButton.icon(
              key: const Key('squad_invite_button'),
              onPressed: () => _invite(context, ref),
              icon: const Icon(Icons.person_add_outlined, size: 16, color: TellyColors.phosphorLime),
              label: Text(
                'Invite',
                style: TellyTypography.caption(color: TellyColors.phosphorLime).copyWith(fontWeight: FontWeight.bold),
              ),
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
                  Text("Couldn't load this squad.", style: TellyTypography.bodyMedium()),
                  TextButton(onPressed: () => ref.invalidate(squadHubProvider(squadId)), child: const Text('Retry')),
                ],
              ),
            ),
          _ => const Center(child: CircularProgressIndicator(color: TellyColors.phosphorLime)),
        },
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    HapticsService.lightImpact();
    final handle = await showDialog<String>(context: context, builder: (_) => const _InviteDialog());
    if (handle == null || handle.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(squadHubProvider(squadId).notifier).invite(handle);
      messenger.showSnackBar(SnackBar(content: Text('Added @${handle.trim().replaceFirst('@', '')}')));
    } on InviteFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't add them. Try again.")));
    }
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: TellyColors.backgroundCard,
        title: Text('Invite by handle', style: TellyTypography.titleMedium()),
        content: TextField(
          key: const Key('squad_invite_field'),
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '@maya'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            key: const Key('squad_invite_confirm'),
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Add'),
          ),
        ],
      );
}

class _Hub extends ConsumerWidget {
  final String squadId;
  final SquadHubState hub;
  const _Hub({required this.squadId, required this.hub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(squadHubProvider(squadId).notifier);
    final hotDebate = hub.debates.firstOrNull;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _MembersRow(members: hub.squad.members),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final (tab, label) in const [
              (SquadTab.consensus, 'Consensus Canon'),
              (SquadTab.watchlist, 'Squad Watchlist'),
              (SquadTab.debates, 'Debates'),
            ])
              Expanded(
                child: InkWell(
                  key: Key('squad_tab_${tab.name}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticsService.selectionClick();
                    controller.selectTab(tab);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: hub.tab == tab ? TellyColors.phosphorLime : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TellyTypography.caption(
                        color: hub.tab == tab ? TellyColors.phosphorLime : TellyColors.textTertiary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (hub.tab != SquadTab.watchlist) ...[
          _CanonSwitcher(selected: hub.mediaType, onSelect: controller.selectCanon),
          const SizedBox(height: 16),
        ],
        if (hub.loadingCanon)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: TellyColors.phosphorLime)),
          )
        else
          ...switch (hub.tab) {
            SquadTab.consensus => [
                if (hotDebate != null) ...[_HotDebateCard(item: hotDebate), const SizedBox(height: 16)],
                Row(
                  children: [
                    Text(
                      'CONSENSUS LEADERBOARD (BORDA COUNT)',
                      style: TellyTypography.caption(color: TellyColors.textTertiary)
                          .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                    ),
                    const Spacer(),
                    Text('${hub.leaderboard.length} Titles', style: TellyTypography.caption()),
                  ],
                ),
                const SizedBox(height: 8),
                if (hub.leaderboard.isEmpty)
                  const _Empty('Nobody in this squad has ranked anything in this canon yet.')
                else
                  ...hub.leaderboard.map((item) => _ConsensusCard(item: item)),
              ],
            SquadTab.watchlist => [
                if (hub.watchlist == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: TellyColors.phosphorLime)),
                  )
                else if (hub.watchlist!.isEmpty)
                  const _Empty('No title is on more than one member’s queue yet.')
                else
                  ...hub.watchlist!.map((item) => _WatchlistTile(item: item)),
              ],
            SquadTab.debates => [
                if (hub.debates.isEmpty)
                  const _Empty('No big disagreements in this canon. Yet.')
                else
                  for (final item in hub.debates) ...[_HotDebateCard(item: item), const SizedBox(height: 8)],
              ],
          },
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center, style: TellyTypography.bodyMedium()),
      );
}

class _MembersRow extends StatelessWidget {
  final List<SquadMember> members;
  const _MembersRow({required this.members});

  @override
  Widget build(BuildContext context) {
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
          Text(
            'MEMBERS (${members.length})',
            style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final member = members[index];
                return InkWell(
                  onTap: member.username.isEmpty ? null : () => context.push(Routes.profile(member.username)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: TellyColors.backgroundCard,
                        child: Text(
                          member.displayName.isNotEmpty ? member.displayName[0] : '?',
                          style: TellyTypography.caption(color: TellyColors.phosphorLime)
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        member.displayName,
                        style: TellyTypography.caption(color: TellyColors.textSecondary)
                            .copyWith(fontWeight: FontWeight.w600),
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

class _CanonSwitcher extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _CanonSwitcher({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget option(String mediaType, String label) => Expanded(
          child: InkWell(
            key: Key('squad_canon_$mediaType'),
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticsService.selectionClick();
              onSelect(mediaType);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: selected == mediaType ? TellyColors.backgroundCard : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected == mediaType ? TellyColors.borderGlass : Colors.transparent),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TellyTypography.caption(
                  color: selected == mediaType ? TellyColors.phosphorLime : TellyColors.textTertiary,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Row(children: [option('tv', '📺 Series Canon'), option('movie', '🎬 Movie Canon')]),
    );
  }
}

class _HotDebateCard extends StatelessWidget {
  final SquadConsensusItem item;
  const _HotDebateCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('squad_debate_${item.titleId}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TellyColors.neonCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.neonCoral.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🔥 SQUAD'S BIGGEST DEBATE: ${item.title.toUpperCase()}",
            style: TellyTypography.caption(color: TellyColors.neonCoral)
                .copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            'Divergence: ${(item.lowestRank - item.championRank).abs()} ranks between '
            '${item.championDisplayName} (#${item.championRank}) and ${item.lowestDisplayName} (#${item.lowestRank})',
            style: TellyTypography.caption(color: TellyColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ConsensusCard extends StatelessWidget {
  final SquadConsensusItem item;
  const _ConsensusCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final top = item.consensusRank <= 3;
    return Container(
      key: Key('squad_consensus_${item.titleId}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: top ? TellyColors.phosphorLime.withValues(alpha: 0.15) : TellyColors.backgroundCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: top ? TellyColors.phosphorLime : TellyColors.borderGlass),
            ),
            child: Text(
              '#${item.consensusRank}',
              style: TellyTypography.monoDigits(color: top ? TellyColors.phosphorLime : TellyColors.textSecondary)
                  .copyWith(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: TellyTypography.bodyLarge(color: TellyColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.totalBordaPoints} pts',
                      style: TellyTypography.monoDigits(color: TellyColors.phosphorLime)
                          .copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Champion: ${item.championDisplayName} (#${item.championRank}) • '
                  'Lowest: ${item.lowestDisplayName} (#${item.lowestRank})',
                  style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(fontSize: 11),
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

class _WatchlistTile extends StatelessWidget {
  final SharedWatchlistItem item;
  const _WatchlistTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('squad_watch_${item.mediaType}_${item.titleId}'),
      contentPadding: EdgeInsets.zero,
      title: Text(item.title, style: TellyTypography.bodyLarge(color: TellyColors.textPrimary)),
      subtitle: Text(
        item.everyone ? 'Everyone wants to watch' : '${item.queuedBy} of ${item.memberCount} want to watch',
        style: TellyTypography.caption(color: item.everyone ? TellyColors.phosphorLime : TellyColors.textTertiary),
      ),
      onTap: () => context.push(Routes.title(item.mediaType, item.titleId)),
    );
  }
}
