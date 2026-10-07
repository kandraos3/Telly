import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/sync/connectivity_signal.dart';
import 'package:telly_app/core/sync/mutation_transport.dart';
import 'package:telly_app/core/sync/sync_engine.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/auth/domain/user_profile.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';

import '../test/fakes/fake_auth_repository.dart';
import 'helpers/test_connectivity_service.dart';

class _RecordingTransport implements MutationTransport {
  final List<String> applied = [];

  @override
  Future<void> apply(PendingMutation mutation) async {
    applied.add(mutation.id);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CUJ-04: Airplane Mode Offline Logging & Sync Resilience (E2E Integration)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final connectivityService = TestConnectivityService(initialOnline: false);
    addTearDown(connectivityService.dispose);

    final transport = _RecordingTransport();
    final auth = FakeAuthRepository(
      signedInUserId: 'usr_cuj04',
      profile: UserProfile(
        id: 'usr_cuj04',
        username: 'resilient_user',
        displayName: 'Resilient User',
        createdAt: DateTime(2026),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        connectivityServiceProvider.overrideWithValue(connectivityService),
        mutationTransportProvider.overrideWithValue(transport),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    container.listen(syncEngineProvider, (_, __) {});

    // 1. Simulate Airplane Mode (Offline)
    connectivityService.setOnline(false);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // 2. Perform 3 offline placements via RankingRepository
    final rankingRepo = container.read(rankingRepositoryProvider);
    final offlineLogs = [
      (76331, 'Succession'),
      (110492, 'Peacemaker'),
      (85937, 'Demon Slayer'),
    ];

    final enqueuedMutationIds = <String>[];
    for (final (titleId, titleName) in offlineLogs) {
      final result = await rankingRepo.commitPlacement(
        candidate: CanonCandidate(titleId: titleId, mediaType: 'tv', title: titleName),
        targetRank: 1,
      );
      enqueuedMutationIds.add(result.mutationId);
    }

    // 3. Assert 0ms optimistic UI update in local Drift SQLite
    final currentCanon = await rankingRepo.getCanon('tv');
    expect(currentCanon.map((r) => r.title), equals(['Demon Slayer', 'Peacemaker', 'Succession']));
    expect(await db.pendingMutationDao.count(), equals(3));
    expect(transport.applied, isEmpty); // No network transactions sent while offline

    // 4. Restore Network Connectivity
    connectivityService.setOnline(true);

    // Wait for SyncEngine to detect connectivity and flush the WAL. A shared CI emulator can take
    // seconds, so wait on the condition with a generous deadline and stop as soon as it holds (#123).
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (transport.applied.length < 3 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    // 5. Assert strict FIFO flush and zero data loss
    expect(transport.applied, equals(enqueuedMutationIds));
    expect(await db.pendingMutationDao.count(), equals(0));

    // Verify all local rankings are now marked as SYNCED
    final syncedCanon = await rankingRepo.getCanon('tv');
    expect(syncedCanon.every((r) => r.syncStatus == 'SYNCED'), isTrue);
  });
}

