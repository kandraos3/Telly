import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_widgets.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: TellyTheme.dark,
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('TellyPrimaryButton Widget Tests', () {
    testWidgets('Renders label and triggers callback on tap', (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrapWidget(
          TellyPrimaryButton(
            label: 'Start Tournament',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Start Tournament'), findsOneWidget);
      await tester.tap(find.text('Start Tournament'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('Disabled state does not trigger callback on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TellyPrimaryButton(
            label: 'Disabled Action',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(find.text('Disabled Action'));
      await tester.pump();
      // No callback was registered, should not throw
    });

    testWidgets('Displays progress indicator when isLoading is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(
          TellyPrimaryButton(
            label: 'Loading Action',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Action'), findsNothing);
    });
  });

  group('TellyFrostedSheet Widget Tests', () {
    testWidgets('Renders child content and drag handle', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TellyFrostedSheet(
            child: Text('Sheet Body Content'),
          ),
        ),
      );

      expect(find.text('Sheet Body Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('TellyNeonBadge Widget Tests', () {
    testWidgets('Renders upset, winner, and god tier badges correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(
          Column(
            children: [
              TellyNeonBadge.upset(label: 'UPSET ALERT'),
              TellyNeonBadge.winner(label: 'DUEL WINNER'),
              TellyNeonBadge.godTier(label: 'GOD TIER'),
            ],
          ),
        ),
      );

      expect(find.text('UPSET ALERT'), findsOneWidget);
      expect(find.text('DUEL WINNER'), findsOneWidget);
      expect(find.text('GOD TIER'), findsOneWidget);
    });
  });

  group('TellyTextField Widget Tests', () {
    testWidgets('Renders hint and updates input text', (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        wrapWidget(
          TellyTextField(
            controller: controller,
            hintText: 'Enter username',
          ),
        ),
      );

      expect(find.text('Enter username'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'kendall_roy');
      await tester.pump();
      expect(controller.text, equals('kendall_roy'));
    });

    testWidgets('Displays error text when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const TellyTextField(
            errorText: 'Username already taken',
          ),
        ),
      );

      expect(find.text('Username already taken'), findsOneWidget);
    });
  });
}

