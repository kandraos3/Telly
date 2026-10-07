import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/analytics/telemetry_service.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/sync/sync_engine.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';
import 'package:telly_app/features/achievements/presentation/widgets/unlock_moment_host.dart';
import 'package:telly_app/features/sharing/data/story_share_service.dart';
import 'package:telly_app/features/sharing/domain/medal_story.dart';
import 'package:telly_app/features/sharing/presentation/widgets/medal_story_card.dart';
import 'package:telly_app/features/sharing/presentation/widgets/story_card_renderer.dart';

import 'achievements_fixtures.dart';

/// The sync engine at rest: no queue, nothing to flush.
class _IdleSync extends SyncEngine {
  @override
  Future<SyncStatus> build() async => const SyncStatus();
}

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.inMemory();
    TelemetryService().reset();
  });
  tearDown(() => db.close());

  Future<(FakeAchievementsRepository, FakeStoryShareService)> pumpHost(
    WidgetTester tester, {
    AchievementsSnapshot? snapshot,
    Object? error,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeAchievementsRepository(snapshot ?? sampleSnapshot(pinned: false))..error = error;
    final share = FakeStoryShareService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        databaseProvider.overrideWithValue(db),
        achievementsRepositoryProvider.overrideWithValue(repo),
        storyShareServiceProvider.overrideWithValue(share),
        syncEngineProvider.overrideWith(_IdleSync.new),
      ],
      child: MaterialApp(
        theme: TellyTheme.dark,
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
        home: const UnlockMomentHost(child: Scaffold(body: Text('home'))),
      ),
    ));
    await tester.pumpAndSettle();
    return (repo, share);
  }

  Future<void> done(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('unlock_moment_done')));
    await tester.pumpAndSettle();
  }

  group('#138 SCR-24 unlock moment', () {
    testWidgets('shows each unseen unlock in turn, oldest first, and marks each seen', (tester) async {
      final (repo, _) = await pumpHost(tester);
      expect(find.byKey(const Key('unlock_moment')), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('4 weeks in a row with at least one ranking.'), findsOneWidget);

      await done(tester);
      expect(repo.seen, ['streak_4']);
      expect(find.text('Ticket Stub'), findsOneWidget);
      expect(find.text("You've ranked 10 films."), findsOneWidget);
      expect(find.textContaining('Unlocked by 4.2% of Telly viewers'), findsOneWidget);
      expect(find.textContaining('2 people you follow have it'), findsOneWidget);

      await done(tester);
      expect(find.text('Upset Artist'), findsOneWidget);
      await done(tester);
      expect(repo.seen, ['streak_4', 'movies_10', 'upset_artist']);
      // #139: one medal_unlocked event per moment.
      expect(
        TelemetryService().recordedEvents.where((e) => e.name == 'medal_unlocked').map((e) => e.properties['achievement_id']),
        ['streak_4', 'movies_10', 'upset_artist'],
      );
      expect(find.byKey(const Key('unlock_moment')), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('nothing unseen: no moment', (tester) async {
      final seen = sampleSnapshot();
      final all = seen.copyWith(medals: [for (final m in seen.medals) m.copyWith(seenAt: DateTime(2026, 10, 4))]);
      final (repo, _) = await pumpHost(tester, snapshot: all);
      expect(find.byKey(const Key('unlock_moment')), findsNothing);
      expect(repo.seen, isEmpty);
    });

    testWidgets('an offline snapshot never shows moments', (tester) async {
      await AchievementsCache(db).write(sampleSnapshot());
      final (repo, _) = await pumpHost(tester, error: Exception('offline'));
      expect(find.byKey(const Key('unlock_moment')), findsNothing);
      expect(repo.seen, isEmpty);
    });

    testWidgets('Pin to profile pins the medal from the moment', (tester) async {
      final (repo, _) = await pumpHost(tester);
      await tester.tap(find.byKey(const Key('unlock_moment_pin')));
      await tester.pumpAndSettle();
      expect(repo.pins, [('streak_4', 1)]);
      expect(find.text('Pinned to profile'), findsOneWidget);
    });

    testWidgets('Share card shares the single-medal story', (tester) async {
      final (_, share) = await pumpHost(tester);
      await tester.tap(find.byKey(const Key('unlock_moment_share')));
      await tester.pumpAndSettle();
      final story = share.sharedMedals.single;
      expect((story.heading, story.isSingle, story.medals.single.name), ('Achievement unlocked', true, 'Regular'));
      expect(story.caption, 'I unlocked the Regular medal on Telly 🏅');
    });

    testWidgets('reduced motion: the confetti is a still frame', (tester) async {
      await pumpHost(tester, reduceMotion: true);
      expect(find.byKey(const Key('unlock_moment')), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('#138 medals share card', () {
    test('showcase story: pinned or latest, with the unlocked count', () {
      final s = sampleSnapshot();
      final story = MedalStory.showcase(s.showcase, unlocked: s.unlockedCount, total: s.visible.length);
      expect((story.heading, story.line), ('My pinned medals', '3 of 6 medals unlocked'));
      expect(story.medals.map((m) => m.name), ['Upset Artist', 'Ticket Stub']);
      final recent = sampleSnapshot(pinned: false);
      expect(MedalStory.showcase(recent.showcase, unlocked: 3, total: 6).heading, 'My latest medals');
    });

    testWidgets('renders offscreen to a 1080×1920 PNG', (tester) async {
      final story = MedalStory.single(sampleSnapshot().medals.first);
      final png = await tester.runAsync(() => StoryCardRenderer.renderOffscreen(MedalStoryCard(story: story)));
      expect(png!.sublist(0, 8), StoryCardRenderer.pngSignature);
    });
  });

  group('#138 MedalShowcase', () {
    test('pinned in slot order, else the three latest unlocks marked Recent, else empty', () {
      expect(sampleSnapshot().showcase.medals.map((m) => m.id), ['upset_artist', 'movies_10']);
      final recent = sampleSnapshot(pinned: false).showcase;
      expect(recent.isRecent, isTrue);
      expect(recent.medals.map((m) => m.id), ['upset_artist', 'movies_10', 'streak_4']);
      expect(recent.semanticLabel, 'Recent medals: Upset Artist, Ticket Stub, Regular');
      expect(sampleSnapshot(empty: true).showcase.isEmpty, isTrue);
    });

    test('a friend\'s showcase is built from user_achievements rows', () {
      final showcase = SupabaseAchievementsRepository.showcaseFromRows([
        {
          'achievement_id': 'movies_100',
          'unlocked_at': '2026-10-02T12:00:00Z',
          'pinned_slot': 1,
          'achievements': {'kind': 'milestone', 'tier': 'gold', 'name': 'Centurion', 'description': '', 'glyph': '100'},
        },
        {
          'achievement_id': 'streak_4',
          'unlocked_at': '2026-10-03T12:00:00Z',
          'pinned_slot': null,
          'achievements': {'kind': 'streak', 'tier': 'bronze', 'name': 'Regular', 'description': '', 'glyph': '4'},
        },
      ]);
      expect(showcase.isRecent, isFalse);
      expect(showcase.medals.map((m) => (m.name, m.tier)), [('Centurion', MedalTier.gold)]);
    });
  });
}
