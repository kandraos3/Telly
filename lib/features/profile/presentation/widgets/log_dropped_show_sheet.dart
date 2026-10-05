import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/features/profile/domain/dropped_show.dart';

/// Modal bottom sheet to log an abandoned TV series into The TV Graveyard (FE-308).
///
/// Implements drop reason taxonomy, season/episode milestone steppers,
/// and "Would you revisit?" toggle per Feature Spec 03 §3.2.
class LogDroppedShowSheet extends ConsumerStatefulWidget {
  final int titleId;
  final String title;
  final int releaseYear;
  final String? posterUrl;
  final ValueChanged<DropDetails> onSaved;

  const LogDroppedShowSheet({
    super.key,
    required this.titleId,
    required this.title,
    required this.releaseYear,
    this.posterUrl,
    required this.onSaved,
  });

  static Future<DropDetails?> show({
    required BuildContext context,
    required int titleId,
    required String title,
    required int releaseYear,
    String? posterUrl,
  }) {
    return showModalBottomSheet<DropDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LogDroppedShowSheet(
        titleId: titleId,
        title: title,
        releaseYear: releaseYear,
        posterUrl: posterUrl,
        onSaved: (details) => Navigator.of(ctx).pop(details),
      ),
    );
  }

  @override
  ConsumerState<LogDroppedShowSheet> createState() => _LogDroppedShowSheetState();
}

class _LogDroppedShowSheetState extends ConsumerState<LogDroppedShowSheet> {
  final TextEditingController _notesController = TextEditingController();

  DropDetails get _form => ref.watch(dropFormProvider);
  DropFormController get _edit => ref.read(dropFormProvider.notifier);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _handleSave() {
    HapticsService.heavyImpact();
    final notes = _notesController.text.trim();
    widget.onSaved(ref.read(dropFormProvider).copyWith(notes: notes.isEmpty ? null : notes));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: TellyColors.borderGlassOf(context)),
          left: BorderSide(color: TellyColors.borderGlassOf(context)),
          right: BorderSide(color: TellyColors.borderGlassOf(context)),
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
                    color: TellyColors.strokeSubtleOf(context),
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
                    style: TellyTypography.labelLarge(color: TellyColors.textPrimaryOf(context)).copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: TellyColors.textTertiaryOf(context)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title banner
              Text(
                '${widget.title} (${widget.releaseYear})',
                style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context)).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Moved out of active canon into dropped tracker',
                style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
              ),
              const SizedBox(height: 20),

              // 2. Drop Point Steppers (Season & Episode)
              Text(
                'DROP POINT (WHERE DID YOU GIVE UP?)',
                style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(
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
                        color: TellyColors.cardOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TellyColors.borderGlassOf(context)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove, size: 16, color: TellyColors.textPrimaryOf(context)),
                            onPressed: _form.season > 1
                                ? () {
                                    HapticsService.selectionClick();
                                    _edit.set(_form.copyWith(season: _form.season - 1));
                                  }
                                : null,
                          ),
                          Text(
                            'Season ${_form.season}',
                            style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, size: 16, color: TellyColors.textPrimaryOf(context)),
                            onPressed: () {
                              HapticsService.selectionClick();
                              _edit.set(_form.copyWith(season: _form.season + 1));
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
                        color: TellyColors.cardOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TellyColors.borderGlassOf(context)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove, size: 16, color: TellyColors.textPrimaryOf(context)),
                            onPressed: (_form.episode ?? 1) > 1
                                ? () {
                                    HapticsService.selectionClick();
                                    _edit.set(_form.copyWith(episode: (_form.episode ?? 1) - 1));
                                  }
                                : null,
                          ),
                          Text(
                            'Episode ${_form.episode ?? 1}',
                            style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, size: 16, color: TellyColors.textPrimaryOf(context)),
                            onPressed: () {
                              HapticsService.selectionClick();
                              _edit.set(_form.copyWith(episode: (_form.episode ?? 0) + 1));
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
                style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DropReasonTaxonomy.allReasons.map((reason) {
                  final isSelected = _form.reason == reason;
                  final icon = DropReasonTaxonomy.getReasonIcon(reason);

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticsService.selectionClick();
                      _edit.set(_form.copyWith(reason: reason));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TellyColors.neonCoral.withValues(alpha: 0.15)
                            : TellyColors.cardOf(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? TellyColors.neonCoral : TellyColors.borderGlassOf(context),
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
                              color: isSelected ? TellyColors.neonCoral : TellyColors.textSecondaryOf(context),
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
                style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(
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
                        _edit.set(_form.copyWith(willingToRevisit: false));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_form.willingToRevisit
                              ? TellyColors.cardOf(context)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: !_form.willingToRevisit ? TellyColors.borderGlassOf(context) : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🚪 Dead & Buried',
                          style: TellyTypography.caption(
                            color: !_form.willingToRevisit ? TellyColors.textPrimaryOf(context) : TellyColors.textTertiaryOf(context),
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
                        _edit.set(_form.copyWith(willingToRevisit: true));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _form.willingToRevisit
                              ? TellyColors.phosphorLime.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _form.willingToRevisit ? TellyColors.phosphorLime : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🔄 Willing to Revisit',
                          style: TellyTypography.caption(
                            color: _form.willingToRevisit ? TellyColors.phosphorLime : TellyColors.textTertiaryOf(context),
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
                  _edit.set(_form.copyWith(notifyOnAcclaim: !_form.notifyOnAcclaim));
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: _form.notifyOnAcclaim,
                      activeColor: TellyColors.phosphorLime,
                      checkColor: Colors.black,
                      onChanged: (val) => _edit.set(_form.copyWith(notifyOnAcclaim: val ?? false)),
                    ),
                    Expanded(
                      child: Text(
                        'Notify me if next season receives ≥ 90% critical acclaim',
                        style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 5. Hot Take Notes
              Text(
                'NOTES / HOT TAKE (OPTIONAL)',
                style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLength: 280,
                maxLines: 2,
                style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context)),
                decoration: InputDecoration(
                  hintText: 'e.g. Lost the mystery once they left the park...',
                  hintStyle: TellyTypography.bodyMedium(color: TellyColors.textTertiaryOf(context)),
                  filled: true,
                  fillColor: TellyColors.cardOf(context),
                  counterStyle: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
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

/// Form state of [LogDroppedShowSheet] (FE-608: no business `setState`).
class DropFormController extends AutoDisposeNotifier<DropDetails> {
  @override
  DropDetails build() => const DropDetails();

  void set(DropDetails details) => state = details;
}

final dropFormProvider = AutoDisposeNotifierProvider<DropFormController, DropDetails>(DropFormController.new);
