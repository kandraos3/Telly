import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/ranking/data/ranking_repository.dart';
import 'package:telly_app/features/sharing/domain/reveal_story.dart';
import 'package:telly_app/features/sharing/presentation/widgets/reveal_story_card.dart';
import 'package:telly_app/features/sharing/presentation/widgets/story_card_renderer.dart';

const _story = RevealStory(
  title: 'The Bear',
  canonLabel: 'Series Canon',
  rank: 3,
  total: 40,
  score: 9.31,
  tierLabel: 'God Tier',
  leaderboard: [
    RevealLeaderboardEntry(rank: 1, title: 'The Wire', score: 10),
    RevealLeaderboardEntry(rank: 2, title: 'Succession', score: 9.75),
    RevealLeaderboardEntry(rank: 3, title: 'The Bear', score: 9.31, isNew: true),
    RevealLeaderboardEntry(rank: 4, title: 'Severance', score: 9.1),
    RevealLeaderboardEntry(rank: 5, title: 'Fleabag', score: 8.9),
  ],
);

void main() {
  group('FE-SHARE-01: rank reveal story', () {
    testWidgets('the card lays out the rank, score, tier and leaderboard in 9:16', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Center(child: RevealStoryCard(story: _story))));

      expect(tester.getSize(find.byType(RevealStoryCard)), RevealStoryCard.logicalSize);
      expect(RevealStoryCard.logicalSize.aspectRatio, closeTo(9 / 16, 1e-9));
      expect(find.text('#3'), findsWidgets);
      expect(find.textContaining('9.31  ·  God Tier'), findsOneWidget);
      for (final e in _story.leaderboard) {
        expect(find.text(e.title), findsWidgets);
      }
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });

    testWidgets('renderOffscreen produces a 1080×1920 PNG without mounting the card', (tester) async {
      final png = await tester.runAsync(() => StoryCardRenderer.renderOffscreen(const RevealStoryCard(story: _story)));

      expect(png!.sublist(0, 8), StoryCardRenderer.pngSignature);
      final ihdr = ByteData.sublistView(png, 16, 24);
      expect((ihdr.getUint32(0), ihdr.getUint32(4)), (1080, 1920));
      expect(find.byType(RevealStoryCard), findsNothing);
    });
  });
}
