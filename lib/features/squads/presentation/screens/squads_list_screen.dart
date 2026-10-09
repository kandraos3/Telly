import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_empty_state.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_neon_badge.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../../core/widgets/telly_section_header.dart';
import '../../../../core/widgets/telly_text_field.dart';
import '../../domain/squad_models.dart';
import '../controllers/squad_controllers.dart';

/// SCR-17a My Squads (FE-608, redesigned in FE-SQUADS-03).
///
/// Squad cards in the Queue list style: a coloured monogram, my role, the description,
/// overlapping member avatars and the member count, all from `get_my_squads`. New squads
/// come from the header's + (as Queue's New list) or the empty state's button.
class SquadsListScreen extends ConsumerWidget {
  const SquadsListScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    HapticsService.lightImpact();
    final name = await TellyFrostedSheet.show<String>(context: context, builder: (_) => const _CreateSquadSheet());
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    try {
      final squad = await ref.read(squadsListProvider.notifier).create(name);
      HapticsService.mediumImpact();
      if (context.mounted) context.push(Routes.squad(squad.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't create the squad.")));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(squadsListProvider);
    final squads = async.valueOrNull;
    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      appBar: TellySubpageAppBar(
        title: 'My Squads',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.social),
        actions: [
          TellyHeaderAction(
            key: const Key('create_squad_button'),
            icon: Icons.add_rounded,
            tooltip: 'New squad',
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: TellyColors.primaryAccentOf(context),
        backgroundColor: TellyColors.cardOf(context),
        onRefresh: () => ref.refresh(squadsListProvider.future),
        child: switch (async) {
          _ when squads != null && squads.isEmpty => _CenteredScroll(
              child: TellyEmptyState(
                key: const Key('squads_empty'),
                icon: Icons.groups_2_outlined,
                title: 'No squads yet',
                message: 'Squads rank together: roommates, a book club, the group chat. '
                    'Create one to start a consensus ranking.',
                actionLabel: 'Create a squad',
                actionIcon: Icons.group_add_rounded,
                actionKey: const Key('create_squad_empty_button'),
                onAction: () => _create(context, ref),
              ),
            ),
          _ when squads != null => ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              children: [
                TellySectionHeader(label: 'MY SQUADS (${squads.length})'),
                const SizedBox(height: 12),
                for (final s in squads) _SquadCard(squad: s),
              ],
            ),
          AsyncError() => _CenteredScroll(
              child: TellyEmptyState(
                key: const Key('squads_error'),
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load your squads",
                message: 'Check your connection and try again.',
                actionLabel: 'Retry',
                actionIcon: Icons.refresh_rounded,
                onAction: () => ref.invalidate(squadsListProvider),
              ),
            ),
          _ => Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
        },
      ),
    );
  }
}

/// Centres [child] in a scroll view, so pull-to-refresh still works on an empty list.
class _CenteredScroll extends StatelessWidget {
  final Widget child;
  const _CenteredScroll({required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      );
}

class _SquadCard extends StatelessWidget {
  final Squad squad;
  const _SquadCard({required this.squad});

  @override
  Widget build(BuildContext context) {
    final count = squad.memberCount;
    final role = squad.myRole;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('squad_row_${squad.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticsService.selectionClick();
            context.push(Routes.squad(squad.id));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SquadMonogram(squad: squad),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              squad.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                                  .copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (role == SquadRole.owner || role == SquadRole.admin) ...[
                            const SizedBox(width: 8),
                            SquadRoleBadge(role: role!),
                          ],
                        ],
                      ),
                      if (squad.description != null && squad.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          squad.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TellyAvatarStack(
                            people: [for (final m in squad.members) (m.displayName.isEmpty ? m.username : m.displayName, m.avatarUrl)],
                            total: count,
                            radius: 13,
                          ),
                          if (squad.members.isNotEmpty) const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$count ${count == 1 ? 'member' : 'members'}',
                              key: Key('squad_member_count_${squad.id}'),
                              style: TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context))
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: TellyColors.textTertiaryOf(context)),
                        ],
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

/// A squad's identity tile: its picture when set, otherwise up to two initials on an
/// accent picked from the squad id, so each squad keeps the same colour (FE-SQUADS-03).
class SquadMonogram extends StatelessWidget {
  final Squad squad;
  final double size;

  const SquadMonogram({super.key, required this.squad, this.size = 48});

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    // Up to two letters, from the last two words: "The Apartment" → TA, "Sci-Fi Book Club" → BC.
    final picked = words.length > 2 ? words.sublist(words.length - 2) : words;
    final letters = [for (final w in picked) w.characters.first.toUpperCase()].join();
    return letters.isEmpty ? '?' : letters;
  }

  Color _accent(BuildContext context) {
    final palette = [
      TellyColors.primaryAccentOf(context),
      TellyColors.electricVioletOf(context),
      TellyColors.warmAmberOf(context),
      TellyColors.electricCyanOf(context),
      TellyColors.neonCoralOf(context),
    ];
    final hash = squad.id.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final radius = BorderRadius.circular(size * 0.3);
    final url = squad.avatarUrl;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: radius,
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: url != null && url.isNotEmpty
          ? ClipRRect(
              borderRadius: radius,
              child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _letters(accent)),
            )
          : _letters(accent),
    );
  }

  Widget _letters(Color accent) => ExcludeSemantics(
        child: Text(
          initials(squad.name),
          style: TellyTypography.titleMedium(color: accent).copyWith(fontWeight: FontWeight.w800, fontSize: size * 0.4),
        ),
      );
}

/// OWNER (accent) or ADMIN (violet) chip; plain members get none (FE-SQUADS-03).
class SquadRoleBadge extends StatelessWidget {
  final SquadRole role;
  const SquadRoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) => TellyNeonBadge(
        label: role == SquadRole.owner ? 'Owner' : 'Admin',
        variant: role == SquadRole.owner ? TellyBadgeVariant.winner : TellyBadgeVariant.tasteMatch,
        // The lime badge colour is not theme-aware; the accent keeps AA contrast on light.
        color: role == SquadRole.owner ? TellyColors.primaryAccentOf(context) : null,
        enableGlow: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      );
}

/// Name a new squad (FE-SQUADS-03): a frosted bottom sheet, as every Telly modal (§6).
class _CreateSquadSheet extends StatefulWidget {
  const _CreateSquadSheet();

  @override
  State<_CreateSquadSheet> createState() => _CreateSquadSheetState();
}

class _CreateSquadSheetState extends State<_CreateSquadSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New squad',
            style: TellyTypography.subpageTitle(color: TellyColors.textPrimaryOf(context)),
          ),
          const SizedBox(height: 4),
          Text(
            'Name it after the group: roommates, a book club, the group chat.',
            style: TellyTypography.bodyMedium(color: TellyColors.textSecondaryOf(context)),
          ),
          const SizedBox(height: 16),
          TellyTextField(
            key: const Key('squad_name_field'),
            controller: _controller,
            autofocus: true,
            hintText: 'The Apartment',
            maxLength: 64,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TellyPrimaryButton(
            key: const Key('squad_create_confirm'),
            label: 'Create squad',
            onPressed: _controller.text.trim().isEmpty ? null : _submit,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
