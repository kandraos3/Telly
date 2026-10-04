import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/telly_theme.dart';

class TellyApp extends ConsumerWidget {
  const TellyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Telly',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: TellyTheme.dark,
      darkTheme: TellyTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
