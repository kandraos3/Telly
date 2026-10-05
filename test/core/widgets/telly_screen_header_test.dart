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

  group('TellySubpageAppBar (FE-HEADER-02)', () {
    final subTitle = find.byKey(const Key('subpage_title'));

    Widget page(TellySubpageAppBar bar, {ThemeData? theme}) =>
        MaterialApp(theme: theme ?? TellyTheme.dark, home: Scaffold(appBar: bar, body: const SizedBox()));

    testWidgets('left-aligned title one step below the tab header, marked as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(page(const TellySubpageAppBar(title: 'Settings')));

      final style = tester.widget<Text>(subTitle).style!;
      expect(style.fontSize, 20, reason: 'one step below the 24 dp tab title');
      expect(style.fontWeight, FontWeight.w800);
      expect(style.letterSpacing, -0.3);
      expect(tester.getTopLeft(subTitle).dx, lessThan(80), reason: 'left-aligned next to the back button');
      expect(tester.getSize(find.byType(AppBar)).height, TellyScreenHeader.height);
      expect(tester.getSemantics(subTitle), matchesSemantics(label: 'Settings', isHeader: true));
      semantics.dispose();
    });

    testWidgets('back by default, close for tasks; both call onNav', (tester) async {
      var navs = 0;
      await tester.pumpWidget(page(TellySubpageAppBar(title: 'Squad', onNav: () => navs++)));
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));

      await tester.pumpWidget(page(TellySubpageAppBar(nav: TellyNavKind.close, title: 'Edit profile', onNav: () => navs++)));
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      expect(navs, 2);
    });

    testWidgets('optional subtitle line and a muted overflow menu', (tester) async {
      String? picked;
      await tester.pumpWidget(page(TellySubpageAppBar(
        title: 'Book Club',
        subtitle: '5 members',
        actions: [
          TellyHeaderMenu<String>(
            itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Leave Squad'))],
            onSelected: (v) => picked = v,
          ),
        ],
      )));

      expect(tester.widget<Text>(find.byKey(const Key('subpage_subtitle'))).data, '5 members');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave Squad'));
      await tester.pumpAndSettle();
      expect(picked, 'leave');
    });

    test('every app bar defaults to the pushed-screen title style in both themes', () {
      for (final theme in [TellyTheme.dark, TellyTheme.light]) {
        expect(theme.appBarTheme.centerTitle, isFalse);
        expect(theme.appBarTheme.titleTextStyle?.fontSize, 20);
        expect(theme.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w800);
      }
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
