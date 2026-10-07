import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_avatar.dart';
import 'package:telly_app/core/widgets/telly_canon_switcher.dart';
import 'package:telly_app/core/widgets/telly_empty_state.dart';
import 'package:telly_app/core/widgets/telly_filter_button.dart';
import 'package:telly_app/core/widgets/telly_section_header.dart';
import 'package:telly_app/core/widgets/telly_segmented_control.dart';

/// FE-UI-01: controls shared by Feed, Queue, Canon and Squads.
void main() {
  Widget host(Widget child, {ThemeData? theme}) =>
      MaterialApp(theme: theme ?? TellyTheme.dark, home: Scaffold(body: Center(child: child)));

  Color textColor(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style!.color!;

  group('TellySegmentedControl', () {
    Widget control(String selected, ValueChanged<String> onChanged, {ThemeData? theme}) => host(
          TellySegmentedControl<String>(
            segments: const [
              TellySegment(value: 'a', label: 'Following', key: Key('seg_a')),
              TellySegment(value: 'b', label: 'Squads', key: Key('seg_b')),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
          theme: theme,
        );

    testWidgets('accents the selected label and reports taps', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(control('a', taps.add));
      expect(textColor(tester, 'Following'), TellyColors.phosphorLime);
      expect(textColor(tester, 'Squads'), TellyColors.textPrimary);

      await tester.tap(find.byKey(const Key('seg_b')));
      expect(taps, ['b']);
    });

    testWidgets('uses the darker lime on the light theme and 48 dp targets', (tester) async {
      await tester.pumpWidget(control('a', (_) {}, theme: TellyTheme.light));
      expect(textColor(tester, 'Following'), const Color(0xFF233B00));
      expect(tester.getSize(find.byKey(const Key('seg_b'))).height, greaterThanOrEqualTo(48));
    });

    testWidgets('marks the selected segment for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(control('b', (_) {}));
      expect(tester.getSemantics(find.text('Squads')), isSemantics(label: 'Squads', isButton: true, isSelected: true));
      semantics.dispose();
    });
  });

  group('TellyCanonSwitcher (compact, #47)', () {
    Color spanColor(WidgetTester tester, String text, String span) {
      final root = tester.widget<Text>(find.text(text)).textSpan! as TextSpan;
      return (root.children!.whereType<TextSpan>().firstWhere((c) => c.text == span)).style!.color!;
    }

    testWidgets('Movies sits left of TV Shows, each with its count and no subtitle', (tester) async {
      await tester.pumpWidget(host(TellyCanonSwitcher(
        selected: 'movie',
        movieCount: 3,
        seriesCount: 5,
        movieKey: const Key('m'),
        seriesKey: const Key('t'),
        onSelect: (_) {},
      )));
      expect(find.text('Movies 3'), findsOneWidget);
      expect(find.text('TV Shows 5'), findsOneWidget);
      expect(find.text('Includes anime'), findsNothing);
      expect(tester.getCenter(find.byKey(const Key('m'))).dx, lessThan(tester.getCenter(find.byKey(const Key('t'))).dx));
    });

    testWidgets('the selected half keeps a primary label with an accent count; the other is muted', (tester) async {
      await tester.pumpWidget(host(TellyCanonSwitcher(selected: 'tv', movieCount: 3, seriesCount: 5, onSelect: (_) {})));
      expect(textColor(tester, 'TV Shows 5'), TellyColors.textPrimary);
      expect(spanColor(tester, 'TV Shows 5', ' 5'), TellyColors.phosphorLime);
      expect(textColor(tester, 'Movies 3'), TellyColors.textTertiary);
      expect(spanColor(tester, 'Movies 3', ' 3'), TellyColors.textTertiary);
    });

    testWidgets('uses the darker accent for the count on light, and 48 dp targets', (tester) async {
      await tester.pumpWidget(host(
        TellyCanonSwitcher(selected: 'movie', movieCount: 3, seriesCount: 5, seriesKey: const Key('t'), onSelect: (_) {}),
        theme: TellyTheme.light,
      ));
      expect(textColor(tester, 'Movies 3'), TellyColors.lightTextPrimary);
      expect(spanColor(tester, 'Movies 3', ' 3'), const Color(0xFF233B00));
      expect(tester.getSize(find.byKey(const Key('t'))).height, greaterThanOrEqualTo(48));
    });

    testWidgets('drops counts when none are given and reports the media type', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(host(TellyCanonSwitcher(selected: 'movie', seriesKey: const Key('t'), onSelect: picked.add)));
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('TV Shows'), findsOneWidget);

      await tester.tap(find.byKey(const Key('t')));
      expect(picked, ['tv']);
    });

    testWidgets('can share a row when expanded', (tester) async {
      await tester.pumpWidget(host(Row(children: [
        Expanded(child: TellyCanonSwitcher(selected: 'movie', margin: EdgeInsets.zero, onSelect: (_) {})),
        TellyFilterButton(activeCount: 0, onPressed: () {}),
      ])));
      expect(tester.takeException(), isNull);
      expect(find.text('Filter'), findsOneWidget);
    });

    testWidgets('marks the selected half for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(TellyCanonSwitcher(selected: 'tv', seriesCount: 5, onSelect: (_) {})));
      expect(tester.getSemantics(find.text('TV Shows 5')), isSemantics(label: 'TV Shows 5', isButton: true, isSelected: true));
      semantics.dispose();
    });
  });

  group('TellyFilterButton (#47)', () {
    testWidgets('idle: Surface chip with no badge, announced as "Filter"', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(host(TellyFilterButton(key: const Key('f'), activeCount: 0, onPressed: () => taps++)));
      expect(find.byKey(const Key('filter_button_badge')), findsNothing);
      expect(textColor(tester, 'Filter'), TellyColors.textSecondary);
      expect(tester.getSemantics(find.byKey(const Key('f'))), isSemantics(label: 'Filter', isButton: true));
      expect(tester.getSize(find.byKey(const Key('f'))).height, greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(const Key('f')));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('active: accent label and a lime badge with the count', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(TellyFilterButton(key: const Key('f'), activeCount: 2, onPressed: () {})));
      expect(find.byKey(const Key('filter_button_badge')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(textColor(tester, 'Filter'), TellyColors.phosphorLime);
      expect(textColor(tester, '2'), TellyFilterButton.badgeText);
      expect(tester.getSemantics(find.byKey(const Key('f'))), isSemantics(label: 'Filter, 2 active', isButton: true));
      semantics.dispose();
    });

    testWidgets('the badge keeps its lime fill on light, and the label uses the light accent', (tester) async {
      await tester.pumpWidget(host(TellyFilterButton(activeCount: 1, onPressed: () {}), theme: TellyTheme.light));
      final badge = tester.widget<Container>(find.byKey(const Key('filter_button_badge')));
      expect((badge.decoration! as BoxDecoration).color, TellyColors.phosphorLime);
      expect(textColor(tester, 'Filter'), TellyColors.lightPhosphorLime);
    });
  });

  group('TellyEmptyState', () {
    testWidgets('shows icon, title, message and a working action', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(host(TellyEmptyState(
        icon: Icons.groups_2_outlined,
        title: 'No squads yet',
        message: 'Create one to start a consensus canon.',
        actionLabel: 'Create a squad',
        actionKey: const Key('cta'),
        onAction: () => tapped++,
      )));
      expect(find.byIcon(Icons.groups_2_outlined), findsOneWidget);
      expect(find.text('No squads yet'), findsOneWidget);
      expect(find.text('Create one to start a consensus canon.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cta')));
      expect(tapped, 1);
    });

    testWidgets('has no button without an action label', (tester) async {
      await tester.pumpWidget(host(const TellyEmptyState(icon: Icons.inbox, title: 'Empty', message: 'Nothing here.')));
      expect(find.byType(InkWell), findsNothing);
    });
  });

  testWidgets('TellySectionHeader is a findable heading with an optional trailing widget', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const TellySectionHeader(label: 'SQUAD TOP 3', trailing: Text('12 titles'))));
    expect(find.text('SQUAD TOP 3'), findsOneWidget);
    expect(find.text('12 titles'), findsOneWidget);
    expect(tester.getSemantics(find.text('SQUAD TOP 3')), isSemantics(label: 'SQUAD TOP 3', isHeader: true));
    semantics.dispose();
  });

  group('TellyAvatarStack', () {
    testWidgets('shows up to max initials, then +N for the rest of the total', (tester) async {
      await tester.pumpWidget(host(const TellyAvatarStack(
        people: [('Jordan', null), ('Maya', null), ('Alex', null), ('Sam', null)],
        total: 7,
        max: 3,
      )));
      expect(find.text('J'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('S'), findsNothing);
      expect(find.text('+4'), findsOneWidget);
    });

    testWidgets('renders nothing for nobody', (tester) async {
      await tester.pumpWidget(host(const TellyAvatarStack(people: [])));
      expect(find.byType(TellyAvatar), findsNothing);
    });
  });
}
