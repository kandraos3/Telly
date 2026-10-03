import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/telly_theme.dart';
import 'core/theme/telly_typography.dart';

class TellyApp extends ConsumerWidget {
  const TellyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Telly',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: TellyTheme.dark,
      darkTheme: TellyTheme.dark,
      home: Scaffold(
        body: Center(
          child: Text(
            'Telly — Your Personal TV Canon',
            style: TellyTypography.titleMedium(),
          ),
        ),
      ),
    );
  }
}

