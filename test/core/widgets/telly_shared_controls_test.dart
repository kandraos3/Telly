import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_avatar.dart';
import 'package:telly_app/core/widgets/telly_canon_switcher.dart';
import 'package:telly_app/core/widgets/telly_empty_state.dart';
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

  group('TellyCanonSwitcher', () {
    testWidgets('Movies sits left of TV Shows, with counts and an optional subtitle', (tester) async {
      await tester.pumpWidget(host(TellyCanonSwitcher(
        selected: 'movie',
        movieCount: 3,
        seriesCount: 5,
        seriesSubtitle: 'Includes anime',
        movieKey: const Key('m'),
        seriesKey: const Key('t'),
        onSelect: (_) {},
      )));
      expect(find.text('Movies (3)'), findsOneWidget);
      expect(find.text('TV Shows (5)'), findsOneWidget);
      expect(find.text('Includes anime'), findsOneWidget);
      expect(tester.getCenter(find.byKey(const Key('m'))).dx, lessThan(tester.getCenter(find.byKey(const Key('t'))).dx));
    });

    testWidgets('drops counts when none are given and reports the media type', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(host(TellyCanonSwitcher(
        selected: 'movie',
        seriesKey: const Key('t'),
        onSelect: picked.add,
      )));
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('TV Shows'), findsOneWidget);
      // The selected half sits on the accent, so its label uses the dark on-accent colour.
      expect(textColor(tester, 'Movies'), const Color(0xFF08090C));

      await tester.tap(find.byKey(const Key('t')));
      expect(picked, ['tv']);
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
