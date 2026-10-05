library report_content_sheet;

import 'package:flutter/material.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';
import 'package:telly_app/features/moderation/domain/moderation_models.dart';

/// Bottom sheet dialog allowing users to flag offensive content or unmarked spoilers.
/// Conforms to `FE-508` and Apple Guideline 1.2 (UGC Safety).
class ReportContentSheet extends StatefulWidget {
  final String contentId;
  final String contentType;
  final String authorUsername;
  final String titleName;
  final ValueChanged<ContentReport>? onSubmitted;

  const ReportContentSheet({
    super.key,
    required this.contentId,
    this.contentType = 'review',
    required this.authorUsername,
    required this.titleName,
    this.onSubmitted,
  });

  static Future<ContentReport?> show({
    required BuildContext context,
    required String contentId,
    String contentType = 'review',
    required String authorUsername,
    required String titleName,
  }) {
    return showModalBottomSheet<ContentReport>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportContentSheet(
        contentId: contentId,
        contentType: contentType,
        authorUsername: authorUsername,
        titleName: titleName,
      ),
    );
  }

  @override
  State<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<ReportContentSheet> {
  ContentReportReason _selectedReason = ContentReportReason.unmarkedSpoiler;
  final TextEditingController _detailsController = TextEditingController();

  bool _muteAuthor = false;
  bool _blockAuthor = false;
  bool _muteTitle = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    final report = ContentReport(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      targetContentId: widget.contentId,
      targetContentType: widget.contentType,
      authorUsername: widget.authorUsername,
      titleName: widget.titleName,
      reason: _selectedReason,
      details: _detailsController.text.trim(),
      createdAt: DateTime.now(),
      mutedAuthor: _muteAuthor,
      blockedAuthor: _blockAuthor,
      mutedTitle: _muteTitle,
    );

    widget.onSubmitted?.call(report);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Report submitted to moderation queue. Thank you.'),
          backgroundColor: TellyColors.cardOf(context),
        ),
      );

    Navigator.of(context).pop(report);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: TellyColors.borderGlassOf(context)),
          left: BorderSide(color: TellyColors.borderGlassOf(context)),
          right: BorderSide(color: TellyColors.borderGlassOf(context)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REPORT CONTENT',
                  style: TellyTypography.titleMedium(color: TellyColors.neonCoral).copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: TellyColors.textSecondaryOf(context), size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              'Reporting @${widget.authorUsername}\'s take on ${widget.titleName}',
              style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
            ),
            const SizedBox(height: 16),

            Text(
              'WHAT IS WRONG WITH THIS POST?',
              style: TellyTypography.labelSmall(color: TellyColors.textSecondaryOf(context)).copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            // Reason Options
            ...ContentReportReason.values.map((reason) {
              final isSelected = _selectedReason == reason;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: TellyColors.cardOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? TellyColors.neonCoral : TellyColors.borderGlassOf(context),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedReason = reason),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? TellyColors.neonCoral : TellyColors.textTertiaryOf(context),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reason.label,
                                style: TextStyle(
                                  color: isSelected ? TellyColors.textPrimaryOf(context) : TellyColors.textSecondaryOf(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reason.description,
                                style: TextStyle(
                                  color: TellyColors.textTertiaryOf(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),

            // Optional Details
            Text(
              'OPTIONAL DETAILS',
              style: TellyTypography.labelSmall(color: TellyColors.textSecondaryOf(context)).copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _detailsController,
              maxLines: 2,
              style: TextStyle(color: TellyColors.textPrimaryOf(context), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Provide additional context (e.g. spoiled ending in line 2)...',
                hintStyle: TextStyle(color: TellyColors.textTertiaryOf(context), fontSize: 12),
                filled: true,
                fillColor: TellyColors.cardOf(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: TellyColors.neonCoral),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Immediate Protective Actions
            Text(
              'ACTIONS FOR YOU',
              style: TellyTypography.labelSmall(color: TellyColors.textSecondaryOf(context)).copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: TellyColors.cardOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TellyColors.borderGlassOf(context)),
              ),
              child: Column(
                children: [
                  _buildActionCheckbox(
                    title: 'Mute @${widget.authorUsername}\'s reviews',
                    value: _muteAuthor,
                    onChanged: (val) => setState(() => _muteAuthor = val ?? false),
                  ),
                  Divider(color: TellyColors.borderGlassOf(context), height: 1),
                  _buildActionCheckbox(
                    title: 'Block @${widget.authorUsername} completely',
                    value: _blockAuthor,
                    onChanged: (val) => setState(() => _blockAuthor = val ?? false),
                  ),
                  Divider(color: TellyColors.borderGlassOf(context), height: 1),
                  _buildActionCheckbox(
                    title: 'Hide "${widget.titleName}" from feed until I finish',
                    value: _muteTitle,
                    onChanged: (val) => setState(() => _muteTitle = val ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TellyPrimaryButton(
              label: 'Submit Report to Moderation',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCheckbox({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: TellyColors.neonCoral,
              checkColor: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: TellyColors.textPrimaryOf(context), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
