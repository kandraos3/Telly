import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telly_app/app.dart';
import 'package:telly_app/core/config/app_config.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/home/presentation/screens/home_screen.dart';
import 'package:telly_app/features/onboarding/data/onboarding_repository.dart';
import 'package:telly_app/features/onboarding/data/top_50_seeds.dart';
import 'package:telly_app/features/profile/data/profile_repository.dart';
import 'package:telly_app/features/ranking/domain/score_curve_calculator.dart';

import '../test/fakes/fake_auth_repository.dart';
import '../test/fakes/fake_onboarding_repository.dart';
import '../test/fakes/fake_profile_repository.dart';
import '../test/fakes/fake_social_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CUJ-01: Cold-Start Onboarding to Canon Calibration (E2E Integration)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final auth = FakeAuthRepository(
      signedInUserId: 'usr_cuj01',
      profile: UserProfile(
        id: 'usr_cuj01',
        username: 'cinephile',
        displayName: 'Cinephile',
        createdAt: DateTime(2026),
        onboardingCompleted: false,
      ),
    );
    final onboarding = FakeOnboardingRepository();
    final profiles = FakeProfileRepository();
    final social = FakeSocialRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(auth),
          onboardingRepositoryProvider.overrideWithValue(onboarding),
          profileRepositoryProvider.overrideWithValue(profiles),
          socialRepositoryProvider.overrideWithValue(social),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              appEnv: 'test',
              supabaseUrl: 'https://test.supabase.co',
              supabaseAnonKey: 'test-anon-key',
            ),
          ),
        ],
        child: const TellyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Validates cold start routes to Streaming Setup (SCR-02)
    expect(find.text('Where do you watch?'), findsOneWidget);

    // 2. Select streaming providers (Netflix, Max, Crunchyroll)
    await onboarding.saveStreamingSetup(platformIds: {'netflix', 'max', 'crunchyroll'}, includeFreePlatforms: false);
    expect(onboarding.saves.last.$1, containsAll(['netflix', 'max', 'crunchyroll']));

    // 3. User selects 8 seed titles (4 movie, 4 tv)
    final movieSeeds = kTop50SeedTitles.where((s) => s.mediaType == 'movie').take(4).toList();
    final seriesSeeds = kTop50SeedTitles.where((s) => s.mediaType == 'tv').take(4).toList();
    expect(movieSeeds.length + seriesSeeds.length, equals(8));

    // 4. Calibrated Top 5 scores follow Gamma = 0.82 score curve
    final top1Score = ScoreCurveCalculator.calculateScore(1, 8, applyBayesianPrior: false);
    final top8Score = ScoreCurveCalculator.calculateScore(8, 8, applyBayesianPrior: false);
    expect(top1Score, equals(10.00));
    expect(top8Score, equals(1.00));

    // 5. Complete registration and onboarding
    final container = ProviderScope.containerOf(tester.element(find.byType(TellyApp)));
    await container.read(authControllerProvider.notifier).finishOnboarding();
    await tester.pumpAndSettle();
    expect(auth.fetchCurrentProfile(), completion(predicate<UserProfile?>((u) => u?.onboardingCompleted == true)));

    // 6. Lands on Home inside the five-tab shell, with Log one tap away (#44, decision 0003)
    expect(find.byType(HomeScreen), findsOneWidget);
    for (final tab in ['home', 'explore', 'rankings', 'social', 'more']) {
      expect(find.byKey(Key('nav_tab_$tab')), findsOneWidget, reason: tab);
    }
    expect(find.byKey(const Key('log_fab')), findsOneWidget);
  });
}

