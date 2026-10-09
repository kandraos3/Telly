import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_floating_nav_bar.dart';

void main() {
  Future<List<Object>> pumpBar(WidgetTester tester, {int index = 0, ThemeData? theme}) async {
    final events = <Object>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: theme ?? TellyTheme.dark,
      home: Scaffold(
        bottomNavigationBar: TellyFloatingNavBar(
          currentIndex: index,
          onTabSelected: events.add,
        ),
      ),
    ));
    return events;
  }

  BoxDecoration surfaceOf(WidgetTester tester) => tester
      .widget<Container>(
        find.descendant(of: find.byKey(const Key('nav_bar_surface')), matching: find.byType(Container)).first,
      )
      .decoration! as BoxDecoration;

  Icon iconOf(WidgetTester tester, String tab) => tester.widget<Icon>(
        find.descendant(of: find.byKey(Key('nav_tab_$tab')), matching: find.byType(Icon)),
      );

  group('#113: TellyFloatingNavBar (component spec §2.1)', () {
    testWidgets('pill is 64 tall, inset 16 from each edge, radius 32', (tester) async {
      await pumpBar(tester);
      final rect = tester.getRect(find.byKey(const Key('nav_bar_surface')));
      expect(rect.height, 64);
      expect(rect.left, 16);
      expect(rect.right, 390 - 16);

      final clip = tester.widget<ClipRRect>(find.byKey(const Key('nav_bar_surface')));
      expect(clip.borderRadius, BorderRadius.circular(32));
    });

    testWidgets('dark surface is #11131A @ 75% with a #242938 1px stroke and blur 24', (tester) async {
      await pumpBar(tester);
      final deco = surfaceOf(tester);
      expect(deco.color, TellyColors.backgroundSurface.withValues(alpha: 0.75));
      expect((deco.border! as Border).top.color, TellyColors.strokeSubtle);
      expect((deco.border! as Border).top.width, 1);
      expect(TellyFloatingNavBar.blurSigma, 24);
    });

    testWidgets('light surface is #FFFFFF @ 90% with a #E2E5EC stroke', (tester) async {
      await pumpBar(tester, theme: TellyTheme.light);
      final deco = surfaceOf(tester);
      expect(deco.color, TellyColors.lightBackgroundSurface.withValues(alpha: 0.9));
      expect((deco.border! as Border).top.color, TellyColors.lightStrokeSubtle);
    });

    testWidgets('shows five equal destinations and no centre action', (tester) async {
      await pumpBar(tester);
      final tabs = ['home', 'explore', 'rankings', 'social', 'more'];
      final widths = [for (final t in tabs) tester.getSize(find.byKey(Key('nav_tab_$t'))).width];
      for (final w in widths) {
        expect(w, closeTo(widths.first, 0.01));
      }
      for (final t in tabs) {
        final size = tester.getSize(find.byKey(Key('nav_tab_$t')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(56));
      }
      expect(find.byKey(const Key('nav_log_button')), findsNothing);
    });

    testWidgets('active tab uses primary text with a phosphor dot; others are tertiary (dark)', (tester) async {
      await pumpBar(tester, index: 3);
      expect(iconOf(tester, 'social').color, TellyColors.textPrimary);
      expect(iconOf(tester, 'home').color, TellyColors.textTertiary);
      final dot = find.descendant(
        of: find.byKey(const Key('nav_tab_social')),
        matching: find.byKey(const Key('nav_active_dot')),
      );
      expect(dot, findsOneWidget);
      expect(find.byKey(const Key('nav_active_dot')), findsOneWidget);
      expect((tester.widget<Container>(dot).decoration! as BoxDecoration).color, TellyColors.phosphorLime);
    });

    testWidgets('active and inactive colours follow the light theme', (tester) async {
      await pumpBar(tester, index: 4, theme: TellyTheme.light);
      expect(iconOf(tester, 'more').color, TellyColors.lightTextPrimary);
      expect(iconOf(tester, 'rankings').color, TellyColors.lightTextTertiary);
      final dot = tester.widget<Container>(find.byKey(const Key('nav_active_dot')));
      expect((dot.decoration! as BoxDecoration).color, TellyColors.lightPhosphorLime);
    });

    testWidgets('tabs report branch indices 0..4', (tester) async {
      final events = await pumpBar(tester);
      for (final tab in ['home', 'explore', 'rankings', 'social', 'more']) {
        await tester.tap(find.byKey(Key('nav_tab_$tab')));
      }
      expect(events, [0, 1, 2, 3, 4]);
    });

    testWidgets('accepts a custom item list', (tester) async {
      final events = <Object>[];
      await tester.pumpWidget(MaterialApp(
        theme: TellyTheme.dark,
        home: Scaffold(
          bottomNavigationBar: TellyFloatingNavBar(
            currentIndex: 0,
            onTabSelected: events.add,
            items: const [TellyNavItem(Icons.home_rounded, 'A'), TellyNavItem(Icons.explore_outlined, 'B')],
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('nav_tab_b')));
      expect(events, [1]);
      expect(find.byKey(const Key('nav_tab_home')), findsNothing);
    });
  });
}
