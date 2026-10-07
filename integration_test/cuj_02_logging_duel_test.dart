import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telly_app/app.dart';
import 'package:telly_app/core/config/app_config.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/discovery/data/discovery_repository.dart';
import 'package:telly_app/features/feed/data/social_repository.dart';
import 'package:telly_app/features/logging/presentation/screens/logging_studio_screen.dart';
import 'package:telly_app/features/ranking/data/canon_hydration.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/ranking/domain/binary_insertion_tournament.dart';
import 'package:telly_app/features/ranking/domain/sentiment_bracket.dart';

import '../test/fakes/fake_auth_repository.dart';
import '../test/fakes/fake_social_repository.dart';
import '../test/helpers/canon_seed.dart';

class _EmptyRemoteCanon implements RemoteCanonSource {
  @override
  Future<List<RemoteRanking>> fetchMyCanon(String userId) async => const [];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CUJ-02 entry: the floating Log button opens logging in one tap from every tab but More (#44)',
      (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(
          signedInUserId: 'usr_cuj02',
          profile: UserProfile(
            id: 'usr_cuj02',
            username: 'logger',
            displayName: 'Logger',
            onboardingCompleted: true,
            createdAt: DateTime(2026),
          ),
        )),
        socialRepositoryProvider.overrideWithValue(FakeSocialRepository()),
        // The same backend fakes as the router widget tests: Explore and Canon must not reach Supabase.
        discoveryRepositoryProvider.overrideWithValue(FakeDiscoveryRepository()),
        remoteCanonSourceProvider.overrideWithValue(_EmptyRemoteCanon()),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        appConfigProvider.overrideWithValue(const AppConfig(
          appEnv: 'test',
          supabaseUrl: 'https://test.supabase.co',
          supabaseAnonKey: 'test-anon-key',
        )),
      ],
      child: const TellyApp(),
    ));
    await tester.pumpAndSettle();

    for (final tab in ['home', 'explore', 'canon', 'social']) {
      await tester.tap(find.byKey(Key('nav_tab_$tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('log_fab'))); // the one tap
      await tester.pumpAndSettle();
      expect(find.byType(LoggingStudioScreen), findsOneWidget, reason: tab);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('nav_tab_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('log_fab')), findsNothing);
  });

  testWidgets('CUJ-02: Complete Movie Logging & Slot Insertion (E2E Integration)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    // 1. Seed existing 25-movie canon
    final existingTitles = List.generate(25, (i) => 'Film #${i + 1}');
    await seedCanon(db, 'movie', existingTitles, baseId: 100);

    final repo = RankingRepository(db);
    final canonBefore = await repo.getCanon('movie');
    expect(canonBefore, hasLength(25));

    // 2. Candidate movie "Dune: Part Two" selected with Masterpiece bracket
    const candidateTitle = 'Dune: Part Two';
    const candidateId = 693134;

    var tournament = BinaryInsertionTournament<String>(
      existingCanon: existingTitles,
      candidate: candidateTitle,
      seedBracket: SentimentBracket.masterpiece,
    );

    int duelCount = 0;
    while (!tournament.isComplete) {
      duelCount++;
      // Candidate wins all duels in Masterpiece bracket
      tournament = tournament.onCandidateWins();
    }

    // Logarithmic comparisons bounded by ceil(log2(searchRange)) <= 4
    expect(duelCount, lessThanOrEqualTo(4));
    expect(tournament.insertionIndex, equals(0)); // Wins and places at #1

    // 3. Commit placement to Drift SQLite with editorial tagging
    final outcome = await repo.commitPlacement(
      candidate: const CanonCandidate(titleId: candidateId, mediaType: 'movie', title: candidateTitle),
      targetRank: 1,
      bracket: SentimentBracket.masterpiece.name,
      duels: const [
        LoggedDuel(winnerTitleId: candidateId, loserTitleId: 100),
      ],
    );

    expect(outcome.mutationId, isNotEmpty);
    expect(outcome.rank, equals(1));
    expect(outcome.score, equals(10.00));

    // 4. Verify canon was updated and all ranks/scores shifted
    final canonAfter = await repo.getCanon('movie');
    expect(canonAfter, hasLength(26));
    expect(canonAfter.first.title, equals(candidateTitle));
    expect(canonAfter.first.rankPosition, equals(1));
    expect(canonAfter.first.calculatedScore, equals(10.00));
    expect(canonAfter[1].title, equals('Film #1'));
    expect(canonAfter[1].rankPosition, equals(2));
    expect(canonAfter[1].calculatedScore, lessThan(10.00));

    // 5. Verify pending mutation enqueued for server sync
    final pendingCount = await db.pendingMutationDao.count();
    expect(pendingCount, equals(1));
  });
}

