import 'package:flutter/material.dart';

import '../theme/telly_colors.dart';
import '../theme/telly_theme.dart';
import '../theme/telly_typography.dart';

/// Shown instead of the app when required build-time configuration is missing.
class ConfigErrorApp extends StatelessWidget {
  final List<String> missing;

  const ConfigErrorApp({super.key, required this.missing});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TellyTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.settings_suggest_outlined, color: TellyColors.neonCoral, size: 40),
                const SizedBox(height: 16),
                Text('Telly is not configured', style: TellyTypography.titleLarge()),
                const SizedBox(height: 8),
                Text(
                  'Missing build-time values: ${missing.join(', ')}.\n\n'
                  'Run with --dart-define-from-file=env/<flavor>.json (see env/example.json).',
                  style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
