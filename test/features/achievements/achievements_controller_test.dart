import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';
import 'package:telly_app/features/achievements/presentation/controllers/achievements_controller.dart';

import 'achievements_fixtures.dart';

void main() {
  group('#137 Medal model', () {
    test('parses a my_achievements row', () {
      final m = Medal.fromJson(medalRow('movies_100', tier: 'gold', name: 'Centurion', threshold: 100, progress: 94));
      expect((m.tier, m.kind, m.isUnlocked, m.progressLabel), (MedalTier.gold, MedalKind.milestone, false, '94/100'));
      expect(m.fraction, closeTo(0.94, 1e-9));
      expect(m.semanticLabel, 'Gold medal, Centurion, 94 of 100');
    });

    test('Taste Twin reads as percentages; rarity reads New under 200 viewers', () {
      final twin = Medal.fromJson(medalRow('taste_twin', tier: 'special', name: 'Taste Twin', threshold: 92, progress: 78));
      expect(twin.progressLabel, '78% / 92%');
      expect(twin.rarityLine, 'New: not enough viewers yet');
      final rare = Medal.fromJson(medalRow('movies_10', rarityPercent: 4.2, rarityIsNew: false));
      expect(rare.rarityLine, 'Unlocked by 4.2% of Telly viewers');
    });

    test('snapshot: special medals hidden until unlocked, pins by slot, recent unlocks, free slot', () {
      final s = sampleSnapshot();
      expect(s.visible.map((m) => m.id), isNot(contains('founding_viewer')));
      expect((s.unlockedCount, s.visible.length), (3, 6));
      expect(s.pinned.map((m) => m.id), ['upset_artist', 'movies_10']);
      expect(s.freePinSlot, 3);
      expect(sampleSnapshot(pinned: false).recent.map((m) => m.id), ['upset_artist', 'movies_10', 'streak_4']);
    });

    test('JSON round-trips for the offline cache', () {
      final s = sampleSnapshot();
      final back = AchievementsSnapshot.fromJson(s.toJson(), offline: true);
      expect(back.toJson(), s.toJson());
      expect(back.offline, isTrue);
      expect(back.medals.first.friends.first.shortName, 'Maya');
    });
  });

  group('#137 AchievementsController', () {
    late AppDatabase db;
    late FakeAchievementsRepository repo;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = FakeAchievementsRepository(sampleSnapshot());
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        achievementsRepositoryProvider.overrideWithValue(repo),
      ]);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('loads from the server and caches the snapshot in Drift', () async {
      final s = await container.read(achievementsControllerProvider.future);
      expect(s.offline, isFalse);
      final cached = await AchievementsCache(db).read();
      expect(cached!.medals.map((m) => m.id), s.medals.map((m) => m.id));
    });

    test('offline: falls back to the cached snapshot, read-only', () async {
      await AchievementsCache(db).write(sampleSnapshot());
      repo.error = Exception('no network');
      final s = await container.read(achievementsControllerProvider.future);
      expect(s.offline, isTrue);
      final medal = s.medals.firstWhere((m) => m.id == 'streak_4');
      await expectLater(
          container.read(achievementsControllerProvider.notifier).pin(medal), throwsA(isA<AchievementsOfflineException>()));
      expect(repo.pins, isEmpty);
    });

    test('with no cache, a failure surfaces as an error', () async {
      repo.error = Exception('no network');
      await expectLater(container.read(achievementsControllerProvider.future), throwsException);
    });

    test('pin takes the free slot, replaces a taken one, and unpin frees it', () async {
      final ctrl = container.read(achievementsControllerProvider.notifier);
      AchievementsSnapshot s = await container.read(achievementsControllerProvider.future);
      Medal byId(String id) => s.medals.firstWhere((m) => m.id == id);

      await ctrl.pin(byId('streak_4'));
      s = container.read(achievementsControllerProvider).requireValue;
      expect(repo.pins.last, ('streak_4', 3));
      expect(s.pinned.map((m) => m.id), ['upset_artist', 'movies_10', 'streak_4']);

      await ctrl.pin(byId('streak_4'), slot: 1);
      s = container.read(achievementsControllerProvider).requireValue;
      expect(s.pinned.map((m) => (m.id, m.pinnedSlot)), [('streak_4', 1), ('movies_10', 2)]);

      await ctrl.unpin(byId('movies_10'));
      s = container.read(achievementsControllerProvider).requireValue;
      expect(repo.unpins, [2]);
      expect(s.pinned.map((m) => m.id), ['streak_4']);
      expect((await AchievementsCache(db).read())!.pinned.map((m) => m.id), ['streak_4'], reason: 'cache follows');
    });
  });
}
