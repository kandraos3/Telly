import 'package:flutter/material.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';

/// Modal bottom sheet to log an abandoned TV series into The TV Graveyard (FE-308).
///
/// Implements drop reason taxonomy, season/episode milestone steppers,
/// and "Would you revisit?" toggle per Feature Spec 03 §3.2.
class LogDroppedShowSheet extends StatefulWidget {
  final int titleId;
  final String title;
  final int releaseYear;
  final String? posterUrl;
  final ValueChanged<DroppedShow> onSaved;

  const LogDroppedShowSheet({
    super.key,
    required this.titleId,
    required this.title,
    required this.releaseYear,
    this.posterUrl,
    required this.onSaved,
  });

  static Future<DroppedShow?> show({
    required BuildContext context,
    required int titleId,
    required String title,
    required int releaseYear,
    String? posterUrl,
  }) {
    return showModalBottomSheet<DroppedShow>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LogDroppedShowSheet(
        titleId: titleId,
        title: title,
        releaseYear: releaseYear,
        posterUrl: posterUrl,
        onSaved: (show) => Navigator.of(ctx).pop(show),
      ),
    );
  }

  @override
  State<LogDroppedShowSheet> createState() => _LogDroppedShowSheetState();
}

class _LogDroppedShowSheetState extends State<LogDroppedShowSheet> {
  int _droppedSeason = 2;
  int _droppedEpisode = 3;
  String _selectedReason = DropReasonTaxonomy.jumpedShark;
  bool _willingToRevisit = false;
  bool _notifyOnAcclaim = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _handleSave() {
    HapticsService.heavyImpact();

    final dropped = DroppedShow(
      id: 'drop-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'current-user-id',
      titleId: widget.titleId,
      title: widget.title,
      posterUrl: widget.posterUrl,
      releaseYear: widget.releaseYear,
      droppedAtSeason: _droppedSeason,
      droppedAtEpisode: _droppedEpisode,
      reason: _selectedReason,
      willingToRevisit: _willingToRevisit,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      notifyOnAcclaim: _notifyOnAcclaim,
      createdAt: DateTime.now(),
    );

    widget.onSaved(dropped);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: TellyColors.borderGlass),
          left: BorderSide(color: TellyColors.borderGlass),
          right: BorderSide(color: TellyColors.borderGlass),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle & Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TellyColors.strokeSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Text('💀', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    'BURY IN TV GRAVEYARD',
                    style: TellyTypography.labelLarge(color: TellyColors.textPrimary).copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: TellyColors.textTertiary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title banner
              Text(
                '${widget.title} (${widget.releaseYear})',
                style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Moved out of active canon into dropped tracker',
                style: TellyTypography.caption(color: TellyColors.textTertiary),
              ),
              const SizedBox(height: 20),

              // 2. Drop Point Steppers (Season & Episode)
              Text(
                'DROP POINT (WHERE DID YOU GIVE UP?)',
                style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Season Stepper
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: TellyColors.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TellyColors.borderGlass),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16, color: TellyColors.textPrimary),
                            onPressed: _droppedSeason > 1
                                ? () {
                                    HapticsService.selectionClick();
                                    setState(() => _droppedSeason--);
                                  }
                                : null,
                          ),
                          Text(
                            'Season $_droppedSeason',
                            style: TellyTypography.bodyMedium(color: TellyColors.textPrimary).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16, color: TellyColors.textPrimary),
                            onPressed: () {
                              HapticsService.selectionClick();
                              setState(() => _droppedSeason++);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Episode Stepper
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: TellyColors.backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TellyColors.borderGlass),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16, color: TellyColors.textPrimary),
                            onPressed: _droppedEpisode > 1
                                ? () {
                                    HapticsService.selectionClick();
                                    setState(() => _droppedEpisode--);
                                  }
                                : null,
                          ),
                          Text(
                            'Episode $_droppedEpisode',
                            style: TellyTypography.bodyMedium(color: TellyColors.textPrimary).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16, color: TellyColors.textPrimary),
                            onPressed: () {
                              HapticsService.selectionClick();
                              setState(() => _droppedEpisode++);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Primary Reason Taxonomy Chips
              Text(
                'PRIMARY DROP REASON',
                style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DropReasonTaxonomy.allReasons.map((reason) {
                  final isSelected = _selectedReason == reason;
                  final icon = DropReasonTaxonomy.getReasonIcon(reason);

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticsService.selectionClick();
                      setState(() {
                        _selectedReason = reason;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TellyColors.neonCoral.withValues(alpha: 0.15)
                            : TellyColors.backgroundCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? TellyColors.neonCoral : TellyColors.borderGlass,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            reason,
                            style: TellyTypography.caption(
                              color: isSelected ? TellyColors.neonCoral : TellyColors.textSecondary,
                            ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 4. "Would You Revisit?" Binary Switch
              Text(
                'WOULD YOU REVISIT?',
                style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        HapticsService.selectionClick();
                        setState(() => _willingToRevisit = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_willingToRevisit
                              ? TellyColors.backgroundCard
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: !_willingToRevisit ? TellyColors.borderGlass : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🚪 Dead & Buried',
                          style: TellyTypography.caption(
                            color: !_willingToRevisit ? TellyColors.textPrimary : TellyColors.textTertiary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        HapticsService.selectionClick();
                        setState(() => _willingToRevisit = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _willingToRevisit
                              ? TellyColors.phosphorLime.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _willingToRevisit ? TellyColors.phosphorLime : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🔄 Willing to Revisit',
                          style: TellyTypography.caption(
                            color: _willingToRevisit ? TellyColors.phosphorLime : TellyColors.textTertiary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notify on acclaim checkbox
              InkWell(
                onTap: () {
                  setState(() => _notifyOnAcclaim = !_notifyOnAcclaim);
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: _notifyOnAcclaim,
                      activeColor: TellyColors.phosphorLime,
                      checkColor: Colors.black,
                      onChanged: (val) => setState(() => _notifyOnAcclaim = val ?? false),
                    ),
                    Expanded(
                      child: Text(
                        'Notify me if next season receives ≥ 90% critical acclaim',
                        style: TellyTypography.caption(color: TellyColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 5. Hot Take Notes
              Text(
                'NOTES / HOT TAKE (OPTIONAL)',
                style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLength: 280,
                maxLines: 2,
                style: TellyTypography.bodyMedium(color: TellyColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Lost the mystery once they left the park...',
                  hintStyle: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
                  filled: true,
                  fillColor: TellyColors.backgroundCard,
                  counterStyle: TellyTypography.caption(color: TellyColors.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TellyColors.borderGlass),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TellyColors.borderGlass),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TellyColors.neonCoral),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Action Button: Bury in Graveyard
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TellyColors.neonCoral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _handleSave,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text(
                    '🪦 Bury in The TV Graveyard',
                    style: TellyTypography.bodyLarge(color: Colors.white).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
