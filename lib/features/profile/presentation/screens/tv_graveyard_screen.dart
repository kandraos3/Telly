import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';
import 'package:telly_app/features/profile/presentation/controllers/graveyard_controller.dart';

/// SCR-18: The TV Graveyard (Dropped / DNF Tracker Screen) (FE-307).
///
/// Dedicated catalog for abandoned television series with milestone markers,
/// reason taxonomies, and "Dead & Buried" vs "Willing to Revisit" tracking.
/// FE-608: backed by `user_dropped_shows` through [graveyardControllerProvider]. New drops
/// come from the Logging Studio (`SCR-09` → "Dropped"), so "+" opens it.
class TvGraveyardScreen extends ConsumerWidget {
  const TvGraveyardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(graveyardControllerProvider);
    final droppedShows = async.valueOrNull ?? const <DroppedShow>[];
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_rounded, color: TellyColors.textPrimaryOf(context)),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.canon),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪦', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'THE TV GRAVEYARD',
              style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context)).copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: TellyColors.neonCoral),
            tooltip: 'Log Dropped Show',
            key: const Key('graveyard_add_button'),
            onPressed: () {
              HapticsService.lightImpact();
              context.push(Routes.log);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Subtitle banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TellyColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TellyColors.borderGlassOf(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: TellyColors.neonCoral, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Shows you abandoned and why (${droppedShows.length} Total). Dropped shows do not affect active canon percentiles.',
                      style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dropped Cards List
            if (async.isLoading && !async.hasValue)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: TellyColors.neonCoral)),
              )
            else if (async.hasError && !async.hasValue)
              Padding(
                key: const Key('graveyard_error'),
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Text("Couldn't load your Graveyard.", style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))),
                    TextButton(
                      onPressed: () => ref.invalidate(graveyardControllerProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (droppedShows.isEmpty)
              _buildEmptyState(context)
            else
              ...droppedShows.map((show) => _buildDroppedCard(context, show)),
          ],
        ),
      ),
    );
  }

  Widget _buildDroppedCard(BuildContext context, DroppedShow show) {
    final reasonIcon = DropReasonTaxonomy.getReasonIcon(show.reason);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(Routes.title(show.mediaType, show.titleId)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: TellyColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TellyColors.strokeSubtleOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Status Badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        show.title.toUpperCase(),
                        style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${show.releaseYear} • ${show.milestoneText}',
                        style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: show.willingToRevisit
                        ? TellyColors.phosphorLime.withValues(alpha: 0.15)
                        : TellyColors.strokeSubtleOf(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: show.willingToRevisit
                          ? TellyColors.phosphorLime
                          : TellyColors.borderGlassOf(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        show.willingToRevisit ? '🔄' : '🚪',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        show.willingToRevisit ? 'Willing to Revisit' : 'Dead & Buried',
                        style: TellyTypography.caption(
                          color: show.willingToRevisit
                              ? TellyColors.phosphorLime
                              : TellyColors.textTertiaryOf(context),
                        ).copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Drop Milestone and Reason Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TellyColors.neonCoral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TellyColors.neonCoral.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reasonIcon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'Reason: “${show.reason}”',
                    style: TellyTypography.caption(color: TellyColors.neonCoral).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Notes / Hot take if present
            if (show.notes != null && show.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '“${show.notes!}”',
                style: TellyTypography.bodyMedium(
                  color: TellyColors.textSecondaryOf(context),
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ],

            // Revisit alert pill if enabled
            if (show.notifyOnAcclaim) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      size: 14, color: TellyColors.warmAmber),
                  const SizedBox(width: 6),
                  Text(
                    'Alert enabled: Notify if next season reaches ≥ 90% acclaim',
                    style: TellyTypography.caption(color: TellyColors.warmAmber).copyWith(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.hotel_class_outlined, size: 48, color: TellyColors.textTertiaryOf(context)),
            const SizedBox(height: 12),
            Text(
              'Your TV Graveyard is Empty',
              style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Never finished a show? Log your abandoned series here!',
              style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
            ),
          ],
        ),
      ),
    );
  }
}
