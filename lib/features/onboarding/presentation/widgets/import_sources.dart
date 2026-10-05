import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';

// Import sources shared by onboarding (SCR-03, FE-606) and Settings (SCR-20, FE-SETTINGS-02).

/// Picks a Letterboxd export and returns its text, or null if cancelled (FE-606).
final csvFilePickerProvider = Provider<Future<String?> Function()>((ref) => () async {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      final bytes = picked?.files.single.bytes;
      return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
    });

/// Owns its controller so it outlives the dialog's exit animation.
class AniListUsernameDialog extends StatefulWidget {
  const AniListUsernameDialog({super.key});

  @override
  State<AniListUsernameDialog> createState() => _AniListUsernameDialogState();
}

class _AniListUsernameDialogState extends State<AniListUsernameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TellyColors.backgroundCard,
      title: Text('AniList username', style: TellyTypography.titleMedium()),
      content: TextField(
        key: const Key('anilist_username_field'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. frieren_fan'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          key: const Key('anilist_import_confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Import'),
        ),
      ],
    );
  }
}
