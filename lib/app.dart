import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/telly_theme.dart';
import 'features/profile/presentation/controllers/settings_controllers.dart';

class TellyApp extends ConsumerWidget {
  const TellyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider).valueOrNull;
    final tellyMode = prefs?.themeMode ?? TellyThemeMode.dark;
    final themeMode = switch (tellyMode) {
      TellyThemeMode.system => ThemeMode.system,
      TellyThemeMode.light => ThemeMode.light,
      TellyThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: 'Telly',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: TellyTheme.light,
      darkTheme: TellyTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
