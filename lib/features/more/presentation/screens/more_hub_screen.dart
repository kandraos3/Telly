import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../achievements/domain/medal.dart';
import '../../../achievements/presentation/controllers/achievements_controller.dart';
import '../../../achievements/presentation/widgets/medal_showcase_row.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// `SCR-22` More hub (epic #44, decision 0003): everything that is not a daily destination.
///
/// Profile card, a full-width Queue tile, feature tiles (Achievements, Wrapped, Graveyard) and a
/// grouped list (Settings). Future entries (Challenges and Your level #50, Invite #51, Telly Pro
/// #52, Help #118) are added only once they ship. Spec: `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` `SCR-22`.
class MoreHubScreen extends ConsumerWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onQueueTap;
  final VoidCallback? onAchievementsTap;
  final VoidCallback? onWrappedTap;
  final VoidCallback? onGraveyardTap;
  final VoidCallback? onSettingsTap;

  const MoreHubScreen({
    super.key,
    this.onProfileTap,
    this.onQueueTap,
    this.onAchievementsTap,
    this.onWrappedTap,
    this.onGraveyardTap,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider.select((s) => s.user));
    final name = me?.displayName ?? '';
    final handle = me?.username;
    // Pinned medals (or the latest unlocks) under the handle once loaded (features/10 §9.2).
    final showcase =
        ref.watch(achievementsControllerProvider.select((s) => s.valueOrNull?.showcase)) ?? MedalShowcase.empty;

    return Scaffold(
      body: TellyFloatingHeaderScrollView(
        header: const TellyScreenHeader(title: 'More'),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          // The header's safe area already clears the floating nav bar.
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileCard(
                name: name,
                handle: handle,
                avatarUrl: me?.avatarUrl,
                showcase: showcase,
                onTap: onProfileTap ?? () => context.go(Routes.canon),
              ),
              const SizedBox(height: 16),
              _QueueTile(onTap: onQueueTap ?? () => context.push(Routes.queue)),
              const SizedBox(height: 12),
              _TileGrid(tiles: [
                // Gamification tiles come first, after Queue (features/10 §9.2).
                _FeatureTile(
                  key: const Key('more_tile_achievements'),
                  icon: Icons.emoji_events_outlined,
                  tone: TellyColors.warmAmberOf(context),
                  label: 'Achievements',
                  subtitle: 'Medals and your streak',
                  onTap: onAchievementsTap ?? () => context.push(Routes.achievements),
                ),
                _FeatureTile(
                  key: const Key('more_tile_wrapped'),
                  icon: Icons.card_giftcard_rounded,
                  tone: TellyColors.primaryAccentOf(context),
                  label: 'Wrapped',
                  subtitle: 'Your year in rankings',
                  onTap: onWrappedTap ?? () => context.push(Routes.wrapped),
                ),
                _FeatureTile(
                  key: const Key('more_tile_graveyard'),
                  icon: Icons.heart_broken_outlined,
                  tone: TellyColors.neonCoralOf(context),
                  label: 'Graveyard',
                  subtitle: 'Dropped and DNF',
                  onTap: onGraveyardTap ?? () => context.push(Routes.graveyard),
                ),
              ]),
              const SizedBox(height: 16),
              _GroupedList(
                rows: [
                  _ListRow(
                    key: const Key('more_row_settings'),
                    icon: Icons.settings_outlined,
                    label: 'Settings and account',
                    onTap: onSettingsTap ?? () => context.push(Routes.settings),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded `surface-raised` card with a 1px `stroke-subtle` border and an ink ripple.
class _HubCard extends StatelessWidget {
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _HubCard({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: TellyColors.strokeOf(context)),
    );
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      child: Material(
        color: TellyColors.surfaceOf(context),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticsService.selectionClick();
            onTap();
          },
          child: ExcludeSemantics(child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}

Widget _chevron(BuildContext context, {double size = 20}) =>
    Icon(Icons.chevron_right_rounded, size: size, color: TellyColors.textTertiaryOf(context));

class _ProfileCard extends StatelessWidget {
  final String name;
  final String? handle;
  final String? avatarUrl;
  final MedalShowcase showcase;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.showcase,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = name.isEmpty ? 'Your profile' : name;
    final subtitle = handle == null || handle!.isEmpty ? 'View profile' : '@$handle · View profile';
    return _HubCard(
      key: const Key('more_profile_card'),
      semanticLabel: showcase.isEmpty ? '$title, $subtitle' : '$title, $subtitle, ${showcase.semanticLabel}',
      onTap: onTap,
      child: Row(
        children: [
          TellyAvatar(name: name.isEmpty ? (handle ?? '') : name, imageUrl: avatarUrl, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
                ),
                if (!showcase.isEmpty) ...[
                  const SizedBox(height: 8),
                  MedalShowcaseRow(key: const Key('more_profile_medals'), showcase: showcase),
                ],
              ],
            ),
          ),
          _chevron(context),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final VoidCallback onTap;
  const _QueueTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _HubCard(
      key: const Key('more_tile_queue'),
      semanticLabel: 'Queue, your watchlist and custom lists',
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.bookmark_outline_rounded, size: 24, color: TellyColors.primaryAccentOf(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Queue',
                  style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your watchlist and custom lists',
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                ),
              ],
            ),
          ),
          _chevron(context, size: 18),
        ],
      ),
    );
  }
}

/// Feature tiles two to a row, 12dp apart; an odd last tile keeps half the width.
class _TileGrid extends StatelessWidget {
  final List<Widget> tiles;
  const _TileGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 12),
              Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  static const height = 104.0;

  final IconData icon;
  final Color tone;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: _HubCard(
        semanticLabel: '$label, $subtitle',
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 24, color: tone),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 52dp rows in one rounded card, separated by dividers.
class _GroupedList extends StatelessWidget {
  final List<_ListRow> rows;
  const _GroupedList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('more_grouped_list'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.strokeOf(context)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: TellyColors.strokeOf(context)),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  static const height = 52.0;

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ListRow({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            HapticsService.selectionClick();
            onTap();
          },
          child: ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: TellyColors.textSecondaryOf(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TellyTypography.bodyLarge(color: TellyColors.textPrimaryOf(context))
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _chevron(context, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
