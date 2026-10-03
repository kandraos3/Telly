import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/squads/domain/squad_models.dart';
import 'package:telly_app/features/squads/presentation/screens/squad_hub_screen.dart';

void main() {
  Widget buildTestableScreen(Widget child) {
    return MaterialApp(
      theme: TellyTheme.darkTheme,
      home: child,
    );
  }

  group('FE-306: SquadHubScreen Widget Tests (SCR-17)', () {
    final sampleSquad = Squad(
      id: 'sq-1',
      name: 'The Apartment',
      createdBy: 'u1',
      members: [
        SquadMember(
          userId: 'u1',
          username: 'jordan',
          displayName: 'Jordan',
          joinedAt: DateTime.now(),
        ),
        SquadMember(
          userId: 'u2',
          username: 'maya',
          displayName: 'Maya',
          joinedAt: DateTime.now(),
        ),
        SquadMember(
          userId: 'u3',
          username: 'alex',
          displayName: 'Alex',
          joinedAt: DateTime.now(),
        ),
      ],
      createdAt: DateTime.now(),
    );

    testWidgets('renders squad name, members, consensus items, and hot debate card', (tester) async {
      await tester.pumpWidget(buildTestableScreen(
        SquadHubScreen(squad: sampleSquad),
      ));
      await tester.pumpAndSettle();

      expect(find.text('THE APARTMENT'), findsOneWidget);
      expect(find.text('MEMBERS (3)'), findsOneWidget);
      expect(find.text('Jordan'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);

      // Verify consensus items
      expect(find.text('Succession'), findsOneWidget);
      expect(find.text('Severance'), findsOneWidget);
      expect(find.text('The Bear'), findsOneWidget);

      // Verify Borda points
      expect(find.textContaining('pts'), findsAtLeastNWidgets(1));

      // Verify Hot debate card
      expect(find.textContaining("SQUAD'S BIGGEST DEBATE"), findsOneWidget);
    });

    testWidgets('switching dual canon toggles series vs movie consensus', (tester) async {
      await tester.pumpWidget(buildTestableScreen(
        SquadHubScreen(squad: sampleSquad),
      ));
      await tester.pumpAndSettle();

      expect(find.text('📺 Series Canon'), findsOneWidget);
      expect(find.text('🎬 Movie Canon'), findsOneWidget);

      await tester.tap(find.text('🎬 Movie Canon'));
      await tester.pumpAndSettle();

      // In movie canon with no movies in sample entries, 0 titles shown
      expect(find.text('0 Titles'), findsOneWidget);

      await tester.tap(find.text('📺 Series Canon'));
      await tester.pumpAndSettle();

      expect(find.text('Succession'), findsOneWidget);
    });
  });
}
