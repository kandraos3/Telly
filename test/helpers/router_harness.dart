import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Hosts [screen] at `/` inside a GoRouter; any other location renders `route:<location>`
/// so tests can assert where a screen navigates without building the destination.
Widget routerHarness(Widget screen, {List<Override> overrides = const [], ThemeData? theme}) {
  Widget stub(BuildContext _, GoRouterState state) => Scaffold(body: Text('route:${state.uri}'));
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      GoRoute(path: '/:a', builder: stub),
      GoRoute(path: '/:a/:b', builder: stub),
      GoRoute(path: '/:a/:b/:c', builder: stub),
      GoRoute(path: '/:a/:b/:c/:d', builder: stub),
    ],
  );
  return ProviderScope(overrides: overrides, child: MaterialApp.router(routerConfig: router, theme: theme));
}
