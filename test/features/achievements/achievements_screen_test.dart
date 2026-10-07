import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/database/database.dart';
import 'package:telly_app/core/database/database_provider.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/achievements/data/achievements_repository.dart';
import 'package:telly_app/features/achievements/domain/medal.dart';
import 'package:telly_app/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:telly_app/features/achievements/presentation/widgets/medal_badge.dart';
import 'package:telly_app/features/sharing/data/story_share_service.dart';

import 'achievements_fixtures.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Future<FakeAchievementsRepository> pump(
    WidgetTester tester, {
    AchievementsSnapshot? snapshot,
    Object? error,
    ThemeData? theme,
    StoryShareService? share,
  }) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeAchievementsRepository(snapshot ?? sampleSnapshot())..error = error;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        databaseProvider.overrideWithValue(db),
        achievementsRepositoryProvider.overrideWithValue(repo),
        storyShareServiceProvider.overrideWithValue(share ?? FakeStoryShareService()),
      ],
      child: MaterialApp(theme: theme ?? TellyTheme.dark, home: const AchievementsScreen()),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  group('#137 SCR-23 Achievements', () {
    testWidgets('summary, streak chip, pinned row, then Milestones, Taste and Streak in order', (tester) async {
      await pump(tester);
      expect(find.text('Achievements'), findsOneWidget);
      expect(find.text('3 of 6', findRichText: true), findsOneWidget,
          reason: 'the locked Founding Viewer is not counted');
      expect(find.text('▲ 6 weeks'), findsOneWidget);
      expect(find.byKey(const Key('achievements_pinned_upset_artist')), findsOneWidget);
      expect(find.byKey(const Key('achievements_pinned_movies_10')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('achievements_pinned_upset_artist'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const Key('achievements_pinned_movies_10'))).dx),
        reason: 'pins sit in slot order',
      );

      double top(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
      expect(top('achievements_summary'), lessThan(top('achievements_pinned_row')));
      expect(top('achievements_pinned_row'), lessThan(top('achievements_section_milestones')));
      expect(top('achievements_section_milestones'), lessThan(top('achievements_section_taste')));
      expect(top('achievements_section_taste'), lessThan(top('achievements_section_streak')));
      expect(find.byKey(const Key('achievements_section_special')), findsNothing);
      expect(find.text('Founding Viewer'), findsNothing);
    });

    testWidgets('locked medals show their progress; unlocked ones a check', (tester) async {
      await pump(tester);
      expect(tester.widget<Text>(find.byKey(const Key('achievements_progress_movies_100'))).data, '94/100');
      expect(tester.widget<Text>(find.byKey(const Key('achievements_progress_taste_twin'))).data, '78% / 92%');
      expect(tester.widget<Text>(find.byKey(const Key('achievements_progress_streak_12'))).data, '6/12');
      expect(find.byKey(const Key('achievements_progress_movies_10')), findsNothing);
      expect(
        find.descendant(of: find.byKey(const Key('achievements_row_movies_10')), matching: find.byIcon(Icons.check_circle_rounded)),
        findsOneWidget,
      );
    });

    testWidgets('nothing pinned: the three most recent unlocks, labelled Recent', (tester) async {
      await pump(tester, snapshot: sampleSnapshot(pinned: false));
      expect(find.text('Recent'), findsOneWidget);
      for (final id in ['upset_artist', 'movies_10', 'streak_4']) {
        expect(find.byKey(Key('achievements_pinned_$id')), findsOneWidget, reason: id);
      }
    });

    testWidgets('new user: every medal locked with progress, and the pinned hint', (tester) async {
      await pump(tester, snapshot: sampleSnapshot(empty: true));
      expect(find.text('Rank titles to earn your first medal'), findsOneWidget);
      expect(find.text('0 of 6', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('achievements_progress_movies_10'))).data, '3/10');
    });

    testWidgets('offline: shows the cached snapshot with the offline banner', (tester) async {
      await AchievementsCache(db).write(sampleSnapshot());
      await pump(tester, error: Exception('offline'));
      expect(find.byKey(const Key('achievements_offline_banner')), findsOneWidget);
      expect(find.text('▲ 6 weeks'), findsOneWidget);
    });

    testWidgets('error with nothing cached: a retry that reloads', (tester) async {
      final repo = await pump(tester, error: Exception('down'));
      expect(find.byKey(const Key('achievements_error')), findsOneWidget);
      repo.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('achievements_summary')), findsOneWidget);
    });

    testWidgets('medal sheet: progress, friends, rarity, and Pin/Unpin', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.byKey(const Key('achievements_row_movies_10')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('medal_sheet')), findsOneWidget);
      expect(find.text('Milestone · Bronze'), findsOneWidget);
      expect(find.text('Maya and Jordan have it'), findsOneWidget);
      expect(find.text('Unlocked by 4.2% of Telly viewers'), findsOneWidget);
      expect(find.text('Unpin from profile'), findsOneWidget);

      await tester.tap(find.byKey(const Key('medal_sheet_pin')));
      await tester.pumpAndSettle();
      expect(repo.unpins, [2]);
      expect(find.text('Pin to profile'), findsOneWidget);
      expect(find.byKey(const Key('achievements_pinned_movies_10')), findsNothing);
    });

    testWidgets('a locked medal sheet shows progress and no pin action', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('achievements_row_movies_100')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('medal_sheet_progress'))).data, '94 of 100');
      expect(find.text('No one you follow has it yet'), findsOneWidget);
      expect(find.text('New: not enough viewers yet'), findsOneWidget);
      expect(find.byKey(const Key('medal_sheet_pin')), findsNothing);
    });

    testWidgets('all three slots taken: pinning asks which medal to replace', (tester) async {
      final full = sampleSnapshot();
      final medals = [
        for (final m in full.medals) m.id == 'streak_4' ? m.copyWith(pinnedSlot: 3) : m,
        Medal.fromJson(medalRow('tv_10', name: 'Ticket Stub TV', progress: 10, unlockedAt: '2026-10-05T12:00:00Z')),
      ];
      final repo = await pump(tester, snapshot: full.copyWith(medals: medals));
      await tester.tap(find.byKey(const Key('achievements_row_tv_10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('medal_sheet_pin')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('medal_sheet_slot_chooser')), findsOneWidget);
      await tester.tap(find.byKey(const Key('medal_sheet_replace_2')));
      await tester.pumpAndSettle();
      expect(repo.pins, [('tv_10', 2)]);
      expect(find.text('Unpin from profile'), findsOneWidget);
    });

    testWidgets('medal visual: tier fills, locked state and semantics (§9.1)', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      expect(find.bySemanticsLabel(RegExp(r'^Gold medal, Centurion, 94 of 100')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Bronze medal, movies_10|^Bronze medal, Ticket Stub, unlocked')), findsWidgets);
      final small = tester.getSize(find.descendant(
          of: find.byKey(const Key('achievements_row_movies_10')), matching: find.byType(MedalBadge)));
      expect(small, Size(MedalSize.small.width, MedalSize.small.height));
      expect(MedalBadge.gradientOf(MedalTier.gold), (TellyColors.tierGodStart, TellyColors.tierGodEnd));
      expect(MedalBadge.gradientOf(MedalTier.special), (TellyColors.tierPrestigeStart, TellyColors.tierPrestigeEnd));
      handle.dispose();
    });

    testWidgets('#138: Share sends a card of the pinned medals; the sheet shares one medal', (tester) async {
      final share = FakeStoryShareService();
      await pump(tester, share: share);
      await tester.tap(find.byKey(const Key('achievements_share')));
      await tester.pumpAndSettle();
      expect(share.sharedMedals.single.heading, 'My pinned medals');
      await tester.tap(find.byKey(const Key('achievements_row_streak_4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('medal_sheet_share')));
      await tester.pumpAndSettle();
      expect(share.sharedMedals.last.medals.single.name, 'Regular');
    });

    testWidgets('#138: no unlocks, no Share', (tester) async {
      await pump(tester, snapshot: sampleSnapshot(empty: true));
      expect(find.byKey(const Key('achievements_share')), findsNothing);
    });

    testWidgets('light theme uses the light tokens', (tester) async {
      await pump(tester, theme: TellyTheme.light);
      final summary = tester.widget<Container>(
          find.descendant(of: find.byKey(const Key('achievements_summary')), matching: find.byType(Container)).first);
      final deco = summary.decoration! as BoxDecoration;
      expect(deco.color, TellyColors.lightBackgroundSurface);
      expect((deco.border! as Border).top.color, TellyColors.lightStrokeSubtle);
    });
  });
}
