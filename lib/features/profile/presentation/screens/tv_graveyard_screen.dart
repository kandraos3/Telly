import 'package:flutter/material.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';
import 'package:telly_app/features/profile/presentation/widgets/log_dropped_show_sheet.dart';

/// SCR-18: The TV Graveyard (Dropped / DNF Tracker Screen) (FE-307).
///
/// Dedicated catalog for abandoned television series with milestone markers,
/// reason taxonomies, and "Dead & Buried" vs "Willing to Revisit" tracking.
class TvGraveyardScreen extends StatefulWidget {
  final List<DroppedShow>? initialDroppedShows;

  /// A show just dropped from the Logging Studio (`SCR-09`, FE-603). Persisting to
  /// `user_dropped_shows` is FE-608.
  final DroppedShow? newlyDropped;

  const TvGraveyardScreen({super.key, this.initialDroppedShows, this.newlyDropped});

  @override
  State<TvGraveyardScreen> createState() => _TvGraveyardScreenState();
}

class _TvGraveyardScreenState extends State<TvGraveyardScreen> {
  late List<DroppedShow> _droppedShows;

  @override
  void initState() {
    super.initState();
    _droppedShows = widget.initialDroppedShows != null
        ? List.from(widget.initialDroppedShows!)
        : _seedInitialGraveyard();
    if (widget.newlyDropped != null) _droppedShows.insert(0, widget.newlyDropped!);
  }

  List<DroppedShow> _seedInitialGraveyard() {
    final now = DateTime.now();
    return [
      DroppedShow(
        id: 'drop-1',
        userId: 'current-user',
        titleId: 501,
        title: 'Westworld',
        releaseYear: 2016,
        droppedAtSeason: 3,
        droppedAtEpisode: 4,
        reason: DropReasonTaxonomy.jumpedShark,
        willingToRevisit: false,
        notes: 'Lost the mystery once they left the park and entered futuristic neo-Los Angeles.',
        notifyOnAcclaim: false,
        createdAt: now.subtract(const Duration(days: 45)),
      ),
      DroppedShow(
        id: 'drop-2',
        userId: 'current-user',
        titleId: 502,
        title: 'Yellowjackets',
        releaseYear: 2021,
        droppedAtSeason: 2,
        droppedAtEpisode: 3,
        reason: DropReasonTaxonomy.pacingSlowed,
        willingToRevisit: true,
        notes: 'Season 1 was electric, but season 2 adult storyline felt meandering.',
        notifyOnAcclaim: true,
        createdAt: now.subtract(const Duration(days: 12)),
      ),
    ];
  }

  void _openLogDroppedSheet() {
    HapticsService.lightImpact();
    LogDroppedShowSheet.show(
      context: context,
      titleId: 999,
      title: 'True Detective: Night Country',
      releaseYear: 2024,
    ).then((dropped) {
      if (dropped != null) {
        setState(() {
          _droppedShows.insert(0, dropped);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TellyColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪦', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'THE TV GRAVEYARD',
              style: TellyTypography.labelLarge(color: TellyColors.textPrimary).copyWith(
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
            onPressed: _openLogDroppedSheet,
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
                color: TellyColors.backgroundSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TellyColors.borderGlass),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: TellyColors.neonCoral, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Shows you abandoned and why (${_droppedShows.length} Total). Dropped shows do not affect active canon percentiles.',
                      style: TellyTypography.caption(color: TellyColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dropped Cards List
            if (_droppedShows.isEmpty)
              _buildEmptyState()
            else
              ..._droppedShows.map((show) => _buildDroppedCard(show)),
          ],
        ),
      ),
    );
  }

  Widget _buildDroppedCard(DroppedShow show) {
    final reasonIcon = DropReasonTaxonomy.getReasonIcon(show.reason);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.strokeSubtle),
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
                        style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${show.releaseYear} • ${show.milestoneText}',
                        style: TellyTypography.caption(color: TellyColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: show.willingToRevisit
                        ? TellyColors.phosphorLime.withValues(alpha: 0.15)
                        : TellyColors.strokeSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: show.willingToRevisit
                          ? TellyColors.phosphorLime
                          : TellyColors.borderGlass,
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
                              : TellyColors.textTertiary,
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
                  color: TellyColors.textSecondary,
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.hotel_class_outlined, size: 48, color: TellyColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Your TV Graveyard is Empty',
              style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Never finished a show? Log your abandoned series here!',
              style: TellyTypography.caption(color: TellyColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
