import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/analytics/telemetry_service.dart';
import 'package:telly_app/core/services/haptics_service.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/auth/data/auth_repository.dart';
import 'package:telly_app/features/levels/data/levels_repository.dart';
import 'package:telly_app/features/levels/domain/level_models.dart';
import 'package:telly_app/features/levels/presentation/controllers/levels_controller.dart';
import 'package:telly_app/features/levels/presentation/controllers/rewards_controller.dart';
import 'package:telly_app/features/levels/presentation/screens/rewards_screen.dart';
import 'package:telly_app/features/levels/presentation/widgets/reward_cosmetics.dart';
import 'package:telly_app/features/profile/presentation/widgets/canon_podium.dart';
import 'package:telly_app/features/ranking/domain/franchise_rollup_service.dart';

import '../../fakes/fake_auth_repository.dart';
import 'levels_fixtures.dart';

void main() {
  setUp(() => TelemetryService().reset());

  List<Override> overrides(FakeLevelsRepository repo) => [
        hapticsEnabledProvider.overrideWith((ref) => false),
        levelsRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedInUserId: 'me')),
        yourLevelControllerProvider.overrideWith(() => _StubLevel()),
      ];

  group('#147 RewardsController', () {
    test('equip is one per kind, reports reward_equipped and frames me at once', () async {
      final repo = FakeLevelsRepository();
      final c = ProviderContainer(overrides: overrides(repo));
      addTearDown(c.dispose);
      final rewards = await c.read(rewardsControllerProvider.future);
      expect(c.read(equippedKindsProvider), {RewardKind.frame});
      expect(c.read(noirCardsProvider), isFalse);

      await c.read(rewardsControllerProvider.notifier).equip(rewards[1]);
      expect(repo.equipped, ['noir_card']);
      expect(c.read(noirCardsProvider), isTrue);
      expect(TelemetryService().recordedEvents.single.toJson()['event'], 'reward_equipped');

      await c.read(rewardsControllerProvider.notifier).unequip(rewards[0]);
      expect(repo.unequipped, [RewardKind.frame]);
      expect(c.read(equippedKindsProvider), {RewardKind.cardStyle});
      expect(c.read(frameDirectoryProvider)['me'], isFalse);
    });

    test('locked rewards never count as equipped', () async {
      final repo = FakeLevelsRepository()
        ..rewardList = const [
          Reward(id: 'gold_podium', name: 'Gold podium tags', kind: RewardKind.canonDecoration, levelRequired: 15,
              equipped: true),
        ];
      final c = ProviderContainer(overrides: overrides(repo));
      addTearDown(c.dispose);
      await c.read(rewardsControllerProvider.future);
      expect(c.read(goldPodiumProvider), isFalse);
    });

    test('the frame directory batches lookups and asks once per user', () async {
      final repo = FakeLevelsRepository()..framed = {'a'};
      final c = ProviderContainer(overrides: overrides(repo));
      addTearDown(c.dispose);
      final dir = c.read(frameDirectoryProvider.notifier);
      dir
        ..ensure('a')
        ..ensure('b')
        ..ensure('a');
      await Future<void>.delayed(Duration.zero);
      dir.ensure('b');
      await Future<void>.delayed(Duration.zero);
      expect(repo.frameQueries, [
        {'a', 'b'}
      ]);
      expect(c.read(frameDirectoryProvider), {'a': true, 'b': false});
    });
  });

  Future<void> pump(WidgetTester tester, Widget child, List<Override> o) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
        key: UniqueKey(), overrides: o, child: MaterialApp(theme: TellyTheme.dark, home: Scaffold(body: child))));
    await tester.pumpAndSettle();
  }

  group('#147 Rewards screen', () {
    testWidgets('unlocked rows toggle Equip/Equipped; locked rows show XP to go', (tester) async {
      final repo = FakeLevelsRepository();
      await pump(tester, const RewardsScreen(), overrides(repo));

      expect(find.text('660 XP to go'), findsOneWidget);
      expect(find.byKey(const Key('reward_equip_gold_podium')), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('reward_equip_lime_frame')), matching: find.text('Equipped')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('reward_equip_noir_card')));
      await tester.pumpAndSettle();
      expect(repo.equipped, ['noir_card']);
      expect(find.descendant(of: find.byKey(const Key('reward_equip_noir_card')), matching: find.text('Equipped')),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('reward_equip_lime_frame')));
      await tester.pumpAndSettle();
      expect(repo.unequipped, [RewardKind.frame]);
      expect(find.descendant(of: find.byKey(const Key('reward_equip_lime_frame')), matching: find.text('Equip')),
          findsOneWidget);
    });
  });

  group('#147 cosmetics', () {
    testWidgets('RewardFrame rings only users who wear the frame', (tester) async {
      final repo = FakeLevelsRepository()..framed = {'a'};
      await pump(
          tester,
          const Column(children: [
            RewardFrame(userId: 'a', child: CircleAvatar(key: Key('av_a'))),
            RewardFrame(userId: 'b', child: CircleAvatar(key: Key('av_b'))),
            RewardFrame(userId: null, child: CircleAvatar(key: Key('av_none'))),
          ]),
          overrides(repo));
      expect(find.byKey(const Key('reward_frame')), findsOneWidget);
      expect(find.ancestor(of: find.byKey(const Key('av_a')), matching: find.byKey(const Key('reward_frame'))),
          findsOneWidget);
      expect(repo.frameQueries, [
        {'a', 'b'}
      ]);
    });

    testWidgets('NoirFilter greys its child only when enabled', (tester) async {
      await pump(tester, const NoirFilter(enabled: false, child: SizedBox()), const []);
      expect(find.byType(ColorFiltered), findsNothing);
      await pump(tester, const NoirFilter(enabled: true, child: SizedBox()), const []);
      expect(find.byType(ColorFiltered), findsOneWidget);
    });

    testWidgets('gold podium tags replace the lime tags when equipped', (tester) async {
      final entries = [
        for (var i = 0; i < 3; i++)
          CanonEntry(id: i, title: 'Title $i', mediaType: 'movie', rankPosition: i + 1, calculatedScore: 9.5 - i),
      ];
      await pump(tester, CanonPodium(entries: entries), const []);
      expect(find.byKey(const Key('podium_gold_tag')), findsNothing);
      await pump(tester, CanonPodium(entries: entries, goldTags: true), const []);
      expect(find.byKey(const Key('podium_gold_tag')), findsNWidgets(3));
    });
  });
}

class _StubLevel extends YourLevelController {
  @override
  Future<YourLevel> build() async => sampleLevel();
}
