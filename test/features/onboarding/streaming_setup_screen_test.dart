import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/onboarding/data/onboarding_repository.dart';
import 'package:telly_app/features/onboarding/presentation/screens/streaming_setup_screen.dart';

import '../../fakes/fake_onboarding_repository.dart';
import '../../helpers/router_harness.dart';

void main() {
  late FakeOnboardingRepository repo;
  setUp(() => repo = FakeOnboardingRepository());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(routerHarness(
      const StreamingSetupScreen(),
      overrides: [onboardingRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
  }

  group('SCR-02 StreamingSetupScreen (FE-108, FE-606)', () {
    testWidgets('renders the 9 SCR-02 platforms, free toggle, skip and an unselected CTA', (tester) async {
      await pump(tester);
      expect(find.text('Where do you watch?'), findsOneWidget);
      for (final name in ['Netflix', 'Max', 'Apple TV+', 'Hulu', 'Disney+', 'Prime Video', 'Crunchyroll', 'Paramount+', 'Criterion']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.textContaining('Include free platforms'), findsOneWidget);
      expect(find.textContaining("I don't have streaming services"), findsOneWidget);
      expect(find.text('CONTINUE →'), findsOneWidget, reason: 'nothing is pre-selected');
    });

    test('platform ids match public.streaming_platforms', () {
      expect(kDefaultStreamingProviders.map((p) => p.id).toSet(), {
        'netflix', 'max', 'apple_tv_plus', 'hulu', 'disney_plus', 'prime_video', 'crunchyroll', 'paramount_plus', 'criterion',
      });
    });

    testWidgets('tapping cards toggles the selection count', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Netflix'));
      await tester.tap(find.text('Disney+'));
      await tester.pumpAndSettle();
      expect(find.text('CONTINUE (2 SELECTED) →'), findsOneWidget);
      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();
      expect(find.text('CONTINUE (1 SELECTED) →'), findsOneWidget);
    });

    testWidgets('Continue saves the selection and free-platform preference, then opens SCR-03', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Apple TV+'));
      await tester.tap(find.text('Crunchyroll'));
      await tester.ensureVisible(find.textContaining('Include free platforms'));
      await tester.tap(find.textContaining('Include free platforms'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('CONTINUE (2 SELECTED) →'));
      await tester.tap(find.text('CONTINUE (2 SELECTED) →'));
      await tester.pumpAndSettle();

      expect(repo.saves.single.$1, {'apple_tv_plus', 'crunchyroll'});
      expect(repo.saves.single.$2, isTrue);
      expect(find.text('route:/onboarding/seeds'), findsOneWidget);
    });

    testWidgets('a failed save stays on SCR-02 and explains why', (tester) async {
      repo.fail = true;
      await pump(tester);
      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE (1 SELECTED) →'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't save your services"), findsOneWidget);
      expect(find.text('Where do you watch?'), findsOneWidget);
    });

    testWidgets('skip saves an empty selection and continues', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.textContaining("I don't have streaming services"));
      await tester.tap(find.textContaining("I don't have streaming services"));
      await tester.pumpAndSettle();
      expect(repo.saves.single.$1, isEmpty);
      expect(repo.saves.single.$2, isFalse);
      expect(find.text('route:/onboarding/seeds'), findsOneWidget);
    });
  });
}
