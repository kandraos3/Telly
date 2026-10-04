import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_floating_nav_bar.dart';

void main() {
  Future<List<Object>> pumpBar(WidgetTester tester, {int index = 0}) async {
    final events = <Object>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: TellyTheme.dark,
      home: Scaffold(
        bottomNavigationBar: TellyFloatingNavBar(
          currentIndex: index,
          onTabSelected: events.add,
          onLogTap: () => events.add('log'),
        ),
      ),
    ));
    return events;
  }

  group('FE-602: TellyFloatingNavBar (component spec §2.1)', () {
    testWidgets('pill is 64 tall, inset 16 from each edge, radius 32', (tester) async {
      await pumpBar(tester);
      final rect = tester.getRect(find.byKey(const Key('nav_bar_surface')));
      expect(rect.height, 64);
      expect(rect.left, 16);
      expect(rect.right, 390 - 16);

      final clip = tester.widget<ClipRRect>(find.byKey(const Key('nav_bar_surface')));
      expect(clip.borderRadius, BorderRadius.circular(32));
    });

    testWidgets('surface is #11131A @ 75% with a #242938 1px stroke and blur 24', (tester) async {
      await pumpBar(tester);
      final container = tester.widget<Container>(
        find.descendant(of: find.byKey(const Key('nav_bar_surface')), matching: find.byType(Container)).first,
      );
      final deco = container.decoration! as BoxDecoration;
      expect(deco.color, TellyColors.backgroundSurface.withValues(alpha: 0.75));
      expect((deco.border! as Border).top.color, TellyColors.strokeSubtle);
      expect((deco.border! as Border).top.width, 1);
      expect(TellyFloatingNavBar.blurSigma, 24);
    });

    testWidgets('center action is a lime button raised 6px with a 12px halo', (tester) async {
      await pumpBar(tester);
      final surface = tester.getRect(find.byKey(const Key('nav_bar_surface')));
      final log = tester.getRect(find.byKey(const Key('nav_log_button')));
      expect(log.center.dx, closeTo(surface.center.dx, 0.01));
      expect(surface.center.dy - log.center.dy, closeTo(6, 0.01));

      final halo = tester.widget<Container>(
        find.descendant(of: find.byKey(const Key('nav_log_button')), matching: find.byType(Container)).first,
      );
      final shadow = (halo.decoration! as BoxDecoration).boxShadow!.single;
      expect(shadow.blurRadius, 12);
      final fill = tester.widget<ColoredBox>(
        find.descendant(of: find.byKey(const Key('nav_log_button')), matching: find.byType(ColoredBox)),
      );
      expect(fill.color, TellyColors.phosphorLime);
    });

    testWidgets('active tab is white with a phosphor dot; others are muted', (tester) async {
      await pumpBar(tester, index: 2);
      Icon iconOf(String tab) => tester.widget<Icon>(
            find.descendant(of: find.byKey(Key('nav_tab_$tab')), matching: find.byType(Icon)),
          );
      expect(iconOf('queue').color, TellyColors.textPrimary);
      expect(iconOf('feed').color, TellyColors.textTertiary);
      expect(
        find.descendant(of: find.byKey(const Key('nav_tab_queue')), matching: find.byKey(const Key('nav_active_dot'))),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nav_active_dot')), findsOneWidget);
    });

    testWidgets('tabs report branch indices 0..3 and the center button reports log', (tester) async {
      final events = await pumpBar(tester);
      for (final tab in ['feed', 'explore', 'queue', 'canon']) {
        await tester.tap(find.byKey(Key('nav_tab_$tab')));
      }
      await tester.tap(find.byKey(const Key('nav_log_button')));
      expect(events, [0, 1, 2, 3, 'log']);
    });
  });
}
