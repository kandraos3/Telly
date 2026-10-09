import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:telly_app/features/onboarding/data/top_50_seeds.dart';
import 'package:telly_app/features/onboarding/presentation/controllers/onboarding_controllers.dart';
import 'package:telly_app/features/onboarding/presentation/screens/onboarding_tournament_screen.dart';

import 'package:telly_app/features/sharing/data/story_share_service.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  testWidgets('FE-606: SCR-04 runs segregated duels, reveals both starter canons and finishes onboarding',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = FakeAuthRepository(
      signedInUserId: 'u1',
      profile: UserProfile(id: 'u1', username: 'maya', displayName: 'Maya', createdAt: DateTime(2026)),
    );
    final fakeShare = FakeStoryShareService();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      hapticsEnabledProvider.overrideWith((ref) => false),
      authRepositoryProvider.overrideWithValue(auth),
      storyShareServiceProvider.overrideWithValue(fakeShare),
    ]);
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, __) {});
    final movies = kTop50SeedTitles.where((s) => s.mediaType == 'movie').take(3);
    final series = kTop50SeedTitles.where((s) => s.mediaType == 'tv' && !s.isAnime).take(5);
    for (final s in [...movies, ...series]) {
      container.read(seedSelectionProvider.notifier).toggle(s);
    }

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: TellyTheme.dark, home: const OnboardingTournamentScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Movie Duel 1 of 3 • Calibrating your Movie Rankings'), findsOneWidget);
    expect(find.text('Too different / Hard to say'), findsOneWidget);

    var duels = 0;
    while (find.byKey(const Key('candidate_card_a')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('candidate_card_a')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      duels++;
      expect(duels, lessThanOrEqualTo(7));
    }
    expect(duels, inInclusiveRange(5, 7));

    // Dual Canons Unveiled
    expect(find.byKey(const Key('confetti_burst')), findsOneWidget);
    expect(find.byKey(const Key('reveal_row_1')), findsOneWidget);
    expect(find.text('10.00'), findsOneWidget);
    expect(find.byKey(const Key('reveal_row_3')), findsOneWidget);
    expect(find.byKey(const Key('reveal_row_4')), findsNothing, reason: 'only 3 movies');
    await tester.tap(find.byKey(const Key('reveal_toggle_tv')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reveal_row_5')), findsOneWidget);

    await tester.tap(find.byKey(const Key('share_starter_canon_button')));
    await tester.pumpAndSettle();
    expect(fakeShare.sharedStories.length, equals(1));
    expect(fakeShare.sharedStories.first.canonLabel, equals('Top Series & Anime'));
    expect(fakeShare.sharedStories.first.topTitles.length, equals(5));

    await tester.tap(find.byKey(const Key('finish_onboarding_button')));
    // No router here to navigate away, so the button keeps its loading spinner.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect((await auth.fetchCurrentProfile())!.onboardingCompleted, isTrue);
    expect(container.read(authControllerProvider).user!.onboardingCompleted, isTrue);
  });
}
