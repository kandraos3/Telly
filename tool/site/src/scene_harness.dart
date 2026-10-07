// Renders one app screen to a PNG for the website (WEB-02), the way the app
// shell would show it: dark theme, iPhone 15 viewport, floating nav bar and
// Log button on tab screens, generated poster art.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/router/app_shell.dart';
import 'package:telly_app/core/widgets/telly_floating_nav_bar.dart';
import 'package:telly_app/core/widgets/telly_log_fab.dart';

/// iPhone 15 viewport in logical pixels.
const phoneSize = Size(393, 852);

/// Output scale: 786 × 1704 PNGs, sharp at the site's phone-frame width on 2× displays.
const shotPixelRatio = 2.0;

class Scene {
  /// File name (`<id>.png`) and the key `site/content.yaml` refers to.
  final String id;

  /// Floating nav bar tab (0 Home, 1 Explore, 2 Canon, 3 Social, 4 More); null hides the bar.
  final int? tab;

  final Widget Function() build;
  final List<Override> Function(AppDatabase db) overrides;

  /// Seeds the local database before the first frame.
  final Future<void> Function(AppDatabase db)? seed;

  /// Taps or scrolls into the state worth showing.
  final Future<void> Function(WidgetTester tester)? interact;

  const Scene({
    required this.id,
    required this.build,
    required this.overrides,
    this.tab,
    this.seed,
    this.interact,
  });
}

Future<void> shootScene(WidgetTester tester, Scene scene, String outDir) async {
  tester.view.physicalSize = phoneSize * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final db = AppDatabase.inMemory();
  addTearDown(db.close);
  await scene.seed?.call(db);

  final boundary = GlobalKey();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => scene.tab == null
            ? Scaffold(body: scene.build())
            : Builder(
                builder: (context) => Stack(
                  children: [
                    Scaffold(
                      extendBody: true,
                      body: scene.build(),
                      bottomNavigationBar: TellyFloatingNavBar(
                        currentIndex: scene.tab!,
                        onTabSelected: (_) {},
                      ),
                    ),
                    if (AppShell.showsLogButton(scene.tab!))
                      Positioned(
                        right: TellyLogFab.rightInset,
                        bottom: TellyLogFab.bottomOffsetOf(context),
                        child: TellyLogFab(onTap: () {}),
                      ),
                  ],
                ),
              ),
      ),
    ],
    // Taps that navigate away are not part of a screenshot.
    errorBuilder: (_, __) => const SizedBox(),
  );

  await tester.pumpWidget(RepaintBoundary(
    key: boundary,
    child: ProviderScope(
      overrides: scene.overrides(db),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: TellyTheme.darkTheme,
        routerConfig: router,
      ),
    ),
  ));
  await _settle(tester);
  if (scene.interact != null) {
    await scene.interact!(tester);
    await _settle(tester);
  }

  final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: shotPixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/${scene.id}.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });

  await tester.pumpWidget(const SizedBox());
}

/// Settles animations, then decodes every on-screen image (poster art renders
/// off the fake-async clock) and settles again.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
}
