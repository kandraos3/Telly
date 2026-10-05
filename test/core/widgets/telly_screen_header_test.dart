import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_screen_header.dart';

/// FE-HEADER-01: shared tab header (design_system/03 §0).
void main() {
  final title = find.byKey(const Key('screen_header_title'));

  Widget host(Widget child) => MaterialApp(theme: TellyTheme.dark, home: Scaffold(body: child));

  Widget scrollingScreen() => host(
        TellyFloatingHeaderScrollView(
          header: TellyScreenHeader(
            title: 'Feed',
            actions: [TellyHeaderAction(key: const Key('a'), icon: Icons.search_rounded, tooltip: 'Search', onPressed: () {})],
          ),
          body: ListView.builder(
            itemCount: 100,
            itemBuilder: (_, i) => SizedBox(height: 80, child: Text('row $i')),
          ),
        ),
      );

  group('TellyScreenHeader', () {
    testWidgets('large sentence-case title, marked as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(const TellyScreenHeader(title: 'Canon')));

      final style = tester.widget<Text>(title).style!;
      expect(tester.widget<Text>(title).data, 'Canon');
      expect(style.fontSize, 24);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.letterSpacing, -0.5);
      expect(tester.getSize(find.byType(TellyScreenHeader)).height, TellyScreenHeader.height);
      expect(tester.getSemantics(title), matchesSemantics(label: 'Canon', isHeader: true));
      semantics.dispose();
    });

    testWidgets('actions are 48 dp tooltipped buttons that fire their callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(TellyScreenHeader(
        title: 'Queue',
        actions: [TellyHeaderAction(key: const Key('sort'), icon: Icons.swap_vert_rounded, tooltip: 'Sort', onPressed: () => taps++)],
      )));

      expect(tester.getSize(find.byKey(const Key('sort'))), const Size(48, 48));
      expect(find.byTooltip('Sort'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sort')));
      expect(taps, 1);
    });

    testWidgets('the last action glyph sits 16 dp from the right edge', (tester) async {
      await tester.pumpWidget(host(TellyScreenHeader(
        title: 'Canon',
        actions: [TellyHeaderAction(key: const Key('x'), icon: Icons.settings_outlined, tooltip: 'Settings', onPressed: () {})],
      )));

      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      expect(screenWidth - tester.getRect(find.byIcon(Icons.settings_outlined)).right, 16);
      expect(tester.getTopLeft(title).dx, 16);
    });
  });

  group('TellyFloatingHeaderScrollView', () {
    testWidgets('hides the header on scroll down and brings it back on scroll up, mid-list', (tester) async {
      await tester.pumpWidget(scrollingScreen());
      expect(title.hitTestable(), findsOneWidget);

      await tester.drag(find.text('row 2'), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(title.hitTestable(), findsNothing, reason: 'scrolled away');
      expect(find.text('row 0'), findsNothing);

      await tester.drag(find.text('row 12'), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(title.hitTestable(), findsOneWidget, reason: 'a short upward scroll snaps it back');
      expect(find.text('row 0'), findsNothing, reason: 'without returning to the top');
      expect(tester.getTopLeft(find.byType(TellyScreenHeader)).dy, greaterThanOrEqualTo(0));
    });
  });
}
