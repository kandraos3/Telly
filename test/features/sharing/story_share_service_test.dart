import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:telly_app/features/sharing/data/story_share_service.dart';
import 'package:telly_app/features/sharing/domain/reveal_story.dart';
import 'package:telly_app/features/sharing/presentation/widgets/story_card_renderer.dart';

void main() {
  group('DEV-601: StoryShareService Tests', () {
    test('SharePlusStoryShareService formats starter canon story text properly', () async {
      String? capturedText;
      String? capturedSubject;

      final service = SharePlusStoryShareService(
        share: (params) async {
          capturedText = params.text;
          capturedSubject = params.subject;
        },
      );

      await service.shareStarterCanon(
        canonLabel: 'Prestige TV Canon',
        topTitles: ['The Wire', 'Succession', 'Severance'],
      );

      expect(capturedSubject, equals('My Prestige TV Canon Top Shows'));
      expect(capturedText, contains('🎬 My Prestige TV Canon on Telly:'));
      expect(capturedText, contains('#1 The Wire'));
      expect(capturedText, contains('#2 Succession'));
      expect(capturedText, contains('#3 Severance'));
      expect(capturedText, contains('https://telly.app'));
    });

    test('FakeStoryShareService records shared stories without platform channels', () async {
      final fake = FakeStoryShareService();

      expect(fake.sharedStories, isEmpty);

      await fake.shareStarterCanon(
        canonLabel: 'Movie Canon',
        topTitles: ['Parasite', 'Interstellar'],
      );

      expect(fake.sharedStories.length, equals(1));
      expect(fake.sharedStories.first.canonLabel, equals('Movie Canon'));
      expect(fake.sharedStories.first.topTitles, equals(['Parasite', 'Interstellar']));
    });

    test('FE-SHARE-01: shareRankReveal shares the rendered 9:16 PNG with a caption', () async {
      ShareParams? captured;
      RevealStory? rendered;
      final png = Uint8List.fromList(StoryCardRenderer.generateSyntheticStoryPng());
      final service = SharePlusStoryShareService(
        share: (params) async => captured = params,
        renderReveal: (story) async {
          rendered = story;
          return png;
        },
      );
      const story = RevealStory(
        title: 'The Bear',
        canonLabel: 'Series Canon',
        rank: 3,
        total: 40,
        score: 9.31,
        tierLabel: 'God Tier',
      );

      await service.shareRankReveal(story);

      expect(rendered, same(story));
      final file = captured!.files!.single;
      expect(file.mimeType, 'image/png');
      expect(await file.readAsBytes(), png);
      expect(captured!.text, 'I just ranked The Bear #3 in my Series Canon on Telly 📺');
    });
  });
}
